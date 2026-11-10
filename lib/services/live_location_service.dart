import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/user_role.dart';
import 'app_session_service.dart';
import 'secure_api.dart';

/// A live GPS record received from Firebase Realtime Database.
class LiveLocationUpdate {
  const LiveLocationUpdate({required this.location, required this.timestamp});

  final LatLng location;
  final DateTime? timestamp;
}

/// Account-owned phone GPS publishing. These sources are never registered canes.
/// Direct caregiver reads are denied; monitoring uses consent-checked HTTP APIs.
class LiveLocationService {
  LiveLocationService._() : api = null;

  @visibleForTesting
  LiveLocationService.forTest(
    this._currentUid,
    this._currentEmail,
    this._write, {
    this.api,
  });

  final SecureApi? api;
  ({String id, String uid, int revision, Map<String, dynamic> payload})?
  _latest;
  Future<void>? _sending;

  String? Function() _currentUid = () => FirebaseAuth.instance.currentUser?.uid;
  String? Function() _currentEmail = () =>
      FirebaseAuth.instance.currentUser?.email;
  Future<void> Function(String, Map<String, dynamic>)? _write;

  static final LiveLocationService instance = LiveLocationService._();

  static const prefsDeviceKey = 'akay_navigation_device_id';
  static const rtdbRoot = 'phone_location';

  String? _deviceId;

  /// Controlled by the consent-based, session-owned breadcrumb recorder.
  bool sharingEnabled = false;

  String? get deviceId => _deviceId;

  @visibleForTesting
  static bool acceptsSample(Object? current, DateTime sampledAt) =>
      current is! Map ||
      current['timestamp'] is! num ||
      (current['timestamp'] as num) < sampledAt.millisecondsSinceEpoch;

  @visibleForTesting
  static String publicationFailure(Object error) {
    if (error is SecureApiException) {
      return switch (error.status) {
        401 => 'sign-in-required',
        403 => 'permission-denied',
        404 => 'backend-endpoint-unavailable',
        410 => 'location-sharing-disabled',
        503 => 'service-unavailable',
        _ => 'request-failed',
      };
    }
    if (error is TimeoutException) return 'timeout';
    if (error is UnsupportedError) return 'unsupported-platform';
    if (error is FirebaseException) {
      return switch (error.code.toLowerCase().replaceAll('_', '-')) {
        'permission-denied' => 'permission-denied',
        'unavailable' => 'service-unavailable',
        'network-request-failed' => 'network-unavailable',
        'invalid-database-url' => 'invalid-database-url',
        _ => 'firebase-error',
      };
    }
    return 'unclassified-error';
  }

  DatabaseReference _refFor(String deviceId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || deviceId != 'phone_$uid') {
      throw StateError('Phone GPS source does not belong to this account.');
    }
    return FirebaseDatabase.instance.ref('$rtdbRoot/$uid');
  }

  /// Watches an existing live-location record without changing the database.
  /// Firebase server timestamps are stored as milliseconds since epoch.
  Stream<LiveLocationUpdate?> watch(String deviceId) {
    return _refFor(deviceId).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return null;

      final data = Map<Object?, Object?>.from(raw);
      final latitude = _asDouble(data['latitude']);
      final longitude = _asDouble(data['longitude']);
      if (latitude == null || longitude == null) return null;

      final timestamp = _asMilliseconds(data['timestamp']);
      return LiveLocationUpdate(
        location: LatLng(latitude, longitude),
        timestamp: timestamp == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(timestamp),
      );
    });
  }

  /// Legacy navigation source label, scoped to the signed-in phone user.
  Future<String> ensureDeviceId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to publish phone GPS.');
    _deviceId = 'phone_$uid';
    return _deviceId!;
  }

  /// Publishes phone GPS to phone_location/{firebaseUid}.
  Future<void> publish({
    required double latitude,
    required double longitude,
    double? speed,
    double? heading,
    double? accuracy,
    String? deviceId,
    DateTime? sampledAt,
  }) async {
    if (!sharingEnabled) return;
    final session = AppSessionService.instance;
    // A retained recording flag must never make a caregiver phone a GPS source.
    if (!session.isLoggedIn || session.role != UserRole.navigator) return;
    final revision = session.identityRevision;
    final uid = _currentUid();
    if (_currentEmail()?.toLowerCase() != session.email?.toLowerCase()) return;
    final sample = sampledAt ?? DateTime.now();
    final age = DateTime.now().difference(sample);
    if (uid == null ||
        age > const Duration(seconds: 45) ||
        age < const Duration(seconds: -30)) {
      return;
    }
    final id = deviceId?.trim().isNotEmpty == true
        ? deviceId!.trim()
        : await ensureDeviceId();
    if (!sharingEnabled ||
        session.identityRevision != revision ||
        session.role != UserRole.navigator ||
        _currentUid() != uid ||
        id != 'phone_$uid') {
      return;
    }
    _deviceId = id;

    final payload = <String, dynamic>{
      'source': 'phone_gps',
      'latitude': latitude,
      'longitude': longitude,
      'speed': _finiteOrZero(speed),
      'heading': _finiteOrNull(heading),
      'accuracy': _finiteOrNull(accuracy),
      'timestamp': sample.millisecondsSinceEpoch,
    };

    final queued = _latest;
    if (queued == null ||
        queued.uid != uid ||
        sample.millisecondsSinceEpoch > (queued.payload['timestamp'] as int)) {
      _latest = (id: id, uid: uid, revision: revision, payload: payload);
    }
    await (_sending ??= _drain().whenComplete(() => _sending = null));
  }

  Future<void> _drain() async {
    while (_latest != null) {
      final update = _latest!;
      _latest = null;
      final session = AppSessionService.instance;
      final age =
          DateTime.now().millisecondsSinceEpoch -
          (update.payload['timestamp'] as int);
      if (!sharingEnabled ||
          !session.isLoggedIn ||
          session.role != UserRole.navigator ||
          session.identityRevision != update.revision ||
          _currentUid() != update.uid ||
          _currentEmail()?.toLowerCase() != session.email?.toLowerCase() ||
          age > 45000 ||
          age < -30000) {
        continue;
      }
      try {
        final write = _write;
        if (write != null) {
          await write(update.id, update.payload);
        } else {
          final receipt = await (api ?? SecureApi.instance).request(
            'PUT',
            '/v2/navigators/${Uri.encodeComponent(update.uid)}/phone-location',
            update.payload,
          );
          if (receipt['accepted'] != true) {
            throw StateError('Location was not acknowledged.');
          }
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint(
            'Phone GPS publication unavailable (${publicationFailure(error)}).',
          );
        }
      }
    }
  }

  Future<void> publishFromPosition(Position position, {String? deviceId}) {
    return publish(
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed,
      heading: position.heading,
      accuracy: position.accuracy,
      deviceId: deviceId,
      sampledAt: position.timestamp,
    );
  }

  /// Clears coordinates and disables sharing with an ordered stop watermark.
  Future<void> clear({String? deviceId}) async {
    final stoppedAt = DateTime.now().millisecondsSinceEpoch;
    try {
      final id = deviceId?.trim().isNotEmpty == true
          ? deviceId!.trim()
          : await ensureDeviceId();
      final uid = _currentUid();
      if (uid == null || id != 'phone_$uid') return;
      if (_latest?.uid == uid) _latest = null;
      await (api ?? SecureApi.instance)
          .request(
            'DELETE',
            '/v2/navigators/${Uri.encodeComponent(uid)}/phone-location',
            {'stoppedAt': stoppedAt},
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Phone GPS cleanup unavailable.');
    }
  }

  double _finiteOrZero(double? value) {
    if (value == null || !value.isFinite || value < 0) return 0;
    return double.parse(value.toStringAsFixed(3));
  }

  double? _finiteOrNull(double? value) {
    if (value == null || !value.isFinite || value < 0) return null;
    return double.parse(value.toStringAsFixed(2));
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? _asMilliseconds(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
