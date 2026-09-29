import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A live GPS record received from Firebase Realtime Database.
class LiveLocationUpdate {
  const LiveLocationUpdate({
    required this.location,
    required this.timestamp,
  });

  final LatLng location;
  final DateTime? timestamp;
}

/// Firebase Realtime Database live GPS stream for caregivers.
///
/// Path shape:
/// ```
/// live_location/
///   {deviceID}/          // same value as navigationsessions.deviceid
///     latitude
///     longitude
///     speed
///     heading
///     accuracy
///     timestamp
/// ```
class LiveLocationService {
  LiveLocationService._();

  static final LiveLocationService instance = LiveLocationService._();

  static const prefsDeviceKey = 'akay_navigation_device_id';
  static const rtdbRoot = 'live_location';

  String? _deviceId;

  String? get deviceId => _deviceId;

  DatabaseReference _refFor(String deviceId) {
    return FirebaseDatabase.instance.ref('$rtdbRoot/$deviceId');
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

  /// Stable device id shared with Postgres `navigationsessions.deviceid`.
  Future<String> ensureDeviceId() async {
    if (_deviceId != null && _deviceId!.isNotEmpty) return _deviceId!;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(prefsDeviceKey);
    if (id == null || id.isEmpty) {
      final fb = FirebaseAuth.instance.currentUser?.uid;
      id = fb != null && fb.isNotEmpty
          ? 'device_$fb'
          : 'device_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';
      await prefs.setString(prefsDeviceKey, id);
    }
    _deviceId = id;
    return id;
  }

  /// Writes / updates `live_location/{deviceID}` for caregiver monitoring.
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
      'deviceID': id,
      'latitude': latitude,
      'longitude': longitude,
      'speed': _finiteOrZero(speed),
      'heading': _finiteOrNull(heading),
      'accuracy': _finiteOrNull(accuracy),
      'timestamp': ServerValue.timestamp,
    };

    try {
      await _refFor(id).update(payload);
      debugPrint(
        'live_location/$id ← lat=$latitude lon=$longitude '
        'speed=${payload['speed']} heading=${payload['heading']}',
      );
    } catch (e) {
      debugPrint('Firebase live_location write error: $e');
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
      debugPrint('Firebase live_location clear error: $e');
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
