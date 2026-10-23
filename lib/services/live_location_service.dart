import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A live GPS record received from Firebase Realtime Database.
class LiveLocationUpdate {
  const LiveLocationUpdate({required this.location, required this.timestamp});

  final LatLng location;
  final DateTime? timestamp;
}

/// Account-owned phone GPS publishing. These sources are never registered canes.
/// Direct caregiver reads are denied; monitoring uses consent-checked HTTP APIs.
class LiveLocationService {
  LiveLocationService._();

  static final LiveLocationService instance = LiveLocationService._();

  static const prefsDeviceKey = 'akay_navigation_device_id';
  static const rtdbRoot = 'phone_location';

  String? _deviceId;

  String? get deviceId => _deviceId;

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
  }) async {
    final id = deviceId?.trim().isNotEmpty == true
        ? deviceId!.trim()
        : await ensureDeviceId();
    _deviceId = id;

    final payload = <String, dynamic>{
      'source': 'phone_gps',
      'latitude': latitude,
      'longitude': longitude,
      'speed': _finiteOrZero(speed),
      'heading': _finiteOrNull(heading),
      'accuracy': _finiteOrNull(accuracy),
      'timestamp': ServerValue.timestamp,
    };

    try {
      await _refFor(id).update(payload);
    } catch (e) {
      debugPrint('Phone GPS publication unavailable.');
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
    );
  }

  /// Removes the live node when navigation ends (optional cleanup).
  Future<void> clear({String? deviceId}) async {
    try {
      final id = deviceId?.trim().isNotEmpty == true
          ? deviceId!.trim()
          : await ensureDeviceId();
      await _refFor(id).remove();
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
