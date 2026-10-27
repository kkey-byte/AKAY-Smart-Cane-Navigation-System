import 'secure_api.dart';
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/route_plan.dart';
import 'app_session_service.dart';
import 'live_location_service.dart';
import 'navigator_location_service.dart';

/// Persists navigation sessions to:
/// - PostgreSQL `navigationsessions` via `/api/navigation/*`
/// - account-owned phone GPS in Firebase (not physical cane telemetry)
class NavigationPersistenceService {
  NavigationPersistenceService._();

  static final NavigationPersistenceService instance =
      NavigationPersistenceService._();

  final _client = http.Client();
  final _liveLocation = LiveLocationService.instance;
  final _location = NavigatorLocationService.instance;

  String? sessionId;
  String? deviceId;
  DateTime? _startedAt;
  double _travelledMeters = 0;
  LatLng? _lastLivePoint;
  Timer? _liveThrottle;
  bool _ending = false;
  int? _identityRevision;
  String? syncError;

  bool get hasActiveSession =>
      sessionId != null &&
      sessionId!.isNotEmpty &&
      _identityRevision == AppSessionService.instance.identityRevision;

  Future<String> _ensureDeviceId() async {
    final id = await _liveLocation.ensureDeviceId();
    deviceId = id;
    return id;
  }

  /// Start a legacy phone navigation session and publish its phone GPS.
  Future<void> startSession({
    required LatLng origin,
    required MapPlace destination,
    String? originAddress,
  }) async {
    final revision = AppSessionService.instance.identityRevision;
    final device = await _ensureDeviceId();
    final session = AppSessionService.instance;
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;

    final payload = <String, dynamic>{
      if (session.userId != null && session.userId!.isNotEmpty)
        'userId': session.userId,
      if (firebaseUid != null && firebaseUid.isNotEmpty)
        'firebaseUid': firebaseUid,
      'deviceId': device,
      'originLatitude': origin.latitude,
      'originLongitude': origin.longitude,
      'originAddress': originAddress ?? '',
      'destinationLatitude': destination.latitude,
      'destinationLongitude': destination.longitude,
      'destinationAddress':
          '${destination.name}${destination.address.isNotEmpty ? ', ${destination.address}' : ''}',
    };

    try {
      final uri = Uri.parse(
        '${SecureApi.preferredBase ?? ApiConfig.baseUrl}/navigation/start',
      );
      if (kReleaseMode && uri.scheme != 'https') {
        throw StateError('HTTPS is required for navigation persistence.');
      }
      final response = await _client
          .post(
            uri,
            headers: {
              'Authorization':
                  'Bearer ${await FirebaseAuth.instance.currentUser?.getIdToken()}',
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      final body = _decode(response.body);
      if (revision != session.identityRevision || !session.isLoggedIn) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('Navigation start failed (${response.statusCode})');
        return;
      }

      final sessionMap = body['session'];
      final id = sessionMap is Map
          ? (sessionMap['sessionId'] ?? sessionMap['sessionid'])?.toString()
          : null;
      if (id == null || id.isEmpty) {
        debugPrint('Navigation start: missing sessionId in response');
        return;
      }

      sessionId = id;
      _identityRevision = revision;
      syncError = null;
      _startedAt = DateTime.now();
      _travelledMeters = 0;
      _lastLivePoint = origin;
      _ending = false;

      await _publishLiveFix(
        latitude: origin.latitude,
        longitude: origin.longitude,
      );

      debugPrint('Phone navigation session started.');
    } catch (_) {
      syncError = 'Navigation session could not be saved.';
      debugPrint('Navigation start unavailable.');
    }
  }

  /// Publish own phone GPS; sync legacy Postgres summary periodically.
  Future<void> publishLiveLocation(LatLng point) async {
    if (!hasActiveSession || _ending) return;

    if (_lastLivePoint != null) {
      _travelledMeters += _metersBetween(_lastLivePoint!, point);
    }
    _lastLivePoint = point;

    await _publishLiveFix(latitude: point.latitude, longitude: point.longitude);

    if (_liveThrottle?.isActive != true) {
      final revision = AppSessionService.instance.identityRevision;
      final activeId = sessionId;
      _liveThrottle = Timer(const Duration(seconds: 8), () {
        if (revision == AppSessionService.instance.identityRevision &&
            activeId == sessionId) {
          unawaited(_syncLiveToPostgres());
        }
      });
    }
  }

  Future<void> _publishLiveFix({
    required double latitude,
    required double longitude,
  }) async {
    final device = await _ensureDeviceId();
    final pos = _location.lastPosition;

    await _liveLocation.publish(
      deviceId: device,
      latitude: latitude,
      longitude: longitude,
      speed: pos?.speed ?? _location.speedMetersPerSecond,
      heading: pos?.heading ?? _location.headingDegrees,
      accuracy: pos?.accuracy ?? _location.accuracyMeters,
      sampledAt: pos?.timestamp,
    );
  }

  Future<void> endSession({bool cancelled = false}) async {
    if (!hasActiveSession || _ending) {
      if (!_liveLocation.sharingEnabled) {
        await _liveLocation.clear(deviceId: deviceId);
      }
      _resetLocal();
      return;
    }
    _ending = true;
    _liveThrottle?.cancel();

    final durationSec = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;
    final hours = durationSec <= 0 ? 0.0 : durationSec / 3600.0;
    final avgSpeed = hours <= 0
        ? 0.0
        : (_travelledMeters / 1000.0) / hours; // km/h

    try {
      final uri = Uri.parse(
        '${SecureApi.preferredBase ?? ApiConfig.baseUrl}/navigation/end',
      );
      if (kReleaseMode && uri.scheme != 'https') {
        throw StateError('HTTPS is required for navigation persistence.');
      }
      final response = await _client
          .post(
            uri,
            headers: {
              'Authorization':
                  'Bearer ${await FirebaseAuth.instance.currentUser?.getIdToken()}',
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'sessionId': sessionId,
              'status': cancelled ? 'Cancelled' : 'Completed',
              'totalDistance': double.parse(
                _travelledMeters.toStringAsFixed(2),
              ),
              'duration': durationSec,
              'averageSpeed': double.parse(avgSpeed.toStringAsFixed(2)),
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Navigation end rejected.');
      }
      syncError = null;
    } catch (_) {
      syncError = 'Navigation end could not be saved. Retry when connected.';
      _ending = false;
      if (!_liveLocation.sharingEnabled) {
        await _liveLocation.clear(deviceId: deviceId);
      }
      return;
    }

    if (!_liveLocation.sharingEnabled) {
      await _liveLocation.clear(deviceId: deviceId);
    }
    _resetLocal();
  }

  Future<void> _syncLiveToPostgres() async {
    if (!hasActiveSession || _ending) return;
    final durationSec = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;
    final hours = durationSec <= 0 ? 0.0 : durationSec / 3600.0;
    final avgSpeed = hours <= 0 ? 0.0 : (_travelledMeters / 1000.0) / hours;

    try {
      final uri = Uri.parse(
        '${SecureApi.preferredBase ?? ApiConfig.baseUrl}/navigation/live',
      );
      if (kReleaseMode && uri.scheme != 'https') {
        throw StateError('HTTPS is required for navigation persistence.');
      }
      final response = await _client
          .put(
            uri,
            headers: {
              'Authorization':
                  'Bearer ${await FirebaseAuth.instance.currentUser?.getIdToken()}',
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'sessionId': sessionId,
              'totalDistance': double.parse(
                _travelledMeters.toStringAsFixed(2),
              ),
              'duration': durationSec,
              'averageSpeed': double.parse(avgSpeed.toStringAsFixed(2)),
              'status': 'Active',
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Navigation update rejected.');
      }
      syncError = null;
    } catch (_) {
      syncError = 'Navigation progress could not be saved.';
    }
  }

  void _resetLocal() {
    _liveThrottle?.cancel();
    _identityRevision = null;
    sessionId = null;
    _startedAt = null;
    _travelledMeters = 0;
    _lastLivePoint = null;
    _ending = false;
  }

  double _metersBetween(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  Map<String, dynamic> _decode(String raw) {
    if (raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }
}
