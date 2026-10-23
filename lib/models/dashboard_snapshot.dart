import 'package:google_maps_flutter/google_maps_flutter.dart';

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.uid,
    required this.name,
    this.position,
    this.locationTime,
    this.heading,
    this.target,
    this.destination,
    this.routeStatus,
    this.routeActive = false,
    this.endedAt,
    this.presence = 'unknown',
    this.presenceTime,
    this.points = const [],
    this.errors = const [],
  });
  final String uid, name, presence;
  final LatLng? position, target;
  final DateTime? locationTime, endedAt, presenceTime;
  bool appActive(DateTime now) =>
      presence == 'active' &&
      presenceTime != null &&
      now.difference(presenceTime!).inSeconds >= -30 &&
      now.difference(presenceTime!) <= const Duration(seconds: 45);
  final double? heading;
  final String? destination, routeStatus;
  final bool routeActive;
  final List<LatLng> points;
  final List<String> errors;
  bool fresh(DateTime now) =>
      locationTime != null &&
      now.difference(locationTime!).inSeconds >= -30 &&
      now.difference(locationTime!) <= const Duration(seconds: 45);
  String status(DateTime now) {
    if (!fresh(now) && !appActive(now)) {
      return position == null && presence == 'unknown'
          ? 'Unavailable'
          : 'Offline';
    }
    if (routeActive) return routeStatus == 'Paused' ? 'Paused' : 'Active';
    if (routeStatus == 'Active' || routeStatus == 'Paused') {
      return 'Unavailable';
    }
    if (routeStatus == 'Completed' &&
        endedAt != null &&
        now.difference(endedAt!).inSeconds >= -30 &&
        now.difference(endedAt!) <= const Duration(minutes: 10)) {
      return 'Arrived';
    }
    return 'Idle';
  }

  String trackingLabel(DateTime now) {
    if (position == null) return 'Waiting for GPS location';
    if (!fresh(now)) return 'Location offline · Last known position';
    if (appActive(now)) return 'Live tracking active · App in use';
    return switch (presence) {
      'active' => 'Recent location · No recent app activity',
      'inactive' => 'Background location updates · App inactive',
      _ => 'Recent location · App activity unknown',
    };
  }

  String get destinationName =>
      clean(destination)
          ?.split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .firstOrNull ??
      (target == null ? 'No destination selected' : 'Pinned destination');
  String get headingLabel {
    if (!routeActive) return 'No active route';
    if (heading == null) return 'Toward $destinationName';
    const directions = [
      'North',
      'North-east',
      'East',
      'South-east',
      'South',
      'South-west',
      'West',
      'North-west',
    ];
    return '${directions[((heading! + 22.5) / 45).floor() % 8]} · ${heading!.round()}°';
  }

  factory DashboardSnapshot.fromJson(Map<String, dynamic> data) {
    final owner = asMap(data['navigator']);
    final navigation = asMap(data['navigation']);
    final location = asMap(data['location']);
    return DashboardSnapshot(
      uid: owner['uid']?.toString() ?? '',
      name: clean(owner['name']) ?? 'Navigator',
      position: point(location),
      locationTime: date(location['time']),
      heading: (number(location['heading'], 360) ?? -1) >= 0
          ? number(location['heading'], 360)
          : null,
      target: point(navigation),
      destination: clean(navigation['destination']),
      routeStatus: clean(navigation['status']),
      routeActive: navigation['active'] == true,
      endedAt: date(navigation['endedAt']),
      presence: asMap(data['presence'])['state']?.toString() ?? 'unknown',
      presenceTime: date(asMap(data['presence'])['updatedAt']),
      points: data['points'] is List
          ? (data['points'] as List)
                .map((raw) => point(asMap(raw)))
                .whereType<LatLng>()
                .toList()
          : const [],
      errors: data['errors'] is List
          ? (data['errors'] as List).whereType<String>().toList()
          : const [],
    );
  }
  static Map<String, dynamic> asMap(Object? raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : {};
  static String? clean(Object? raw) =>
      raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
  static DateTime? date(Object? raw) {
    if (raw is num && raw.isFinite && raw >= 0 && raw <= 8640000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  static double? number(Object? raw, double bound) {
    if (raw == null || raw is bool) return null;
    final value = raw is num
        ? raw.toDouble()
        : raw is String
        ? double.tryParse(raw)
        : null;
    return value != null && value.isFinite && value.abs() <= bound
        ? value
        : null;
  }

  static LatLng? point(Map<String, dynamic> raw) {
    final lat = number(raw['latitude'], 90),
        lon = number(raw['longitude'], 180);
    return lat == null || lon == null ? null : LatLng(lat, lon);
  }
}
