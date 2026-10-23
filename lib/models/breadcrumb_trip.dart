import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BreadcrumbPoint {
  const BreadcrumbPoint(
    this.latitude,
    this.longitude,
    this.time,
    this.accuracy,
  );
  final double latitude;
  final double longitude;
  final DateTime time;
  final double accuracy;
  LatLng get location => LatLng(latitude, longitude);

  Map<String, Object> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'time': time.millisecondsSinceEpoch,
    'accuracy': accuracy,
  };

  static BreadcrumbPoint? parse(Object? raw) {
    if (raw is! Map) return null;
    final lat = raw['latitude'];
    final lon = raw['longitude'];
    final time = raw['time'];
    final accuracy = raw['accuracy'];
    if (lat is! num ||
        lon is! num ||
        time is! num ||
        accuracy is! num ||
        !lat.isFinite ||
        !lon.isFinite ||
        !accuracy.isFinite ||
        !time.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180 ||
        accuracy < 0 ||
        time < 0 ||
        time > 8640000000000000) {
      return null;
    }
    return BreadcrumbPoint(
      lat.toDouble(),
      lon.toDouble(),
      DateTime.fromMillisecondsSinceEpoch(time.toInt()),
      accuracy.toDouble(),
    );
  }
}

class BreadcrumbTrip {
  const BreadcrumbTrip({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.startedAt,
    required this.points,
    this.status = 'recording',
    this.endedAt,
  });
  final String id;
  final String ownerId;
  final String name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String status;
  final List<BreadcrumbPoint> points;
  bool get isRecording => status == 'recording';
  bool isFresh(DateTime now) =>
      isRecording &&
      points.isNotEmpty &&
      now.difference(points.last.time).inSeconds >= -30 &&
      now.difference(points.last.time) <= const Duration(seconds: 45);

  BreadcrumbTrip copyWith({
    List<BreadcrumbPoint>? points,
    String? status,
    DateTime? endedAt,
  }) => BreadcrumbTrip(
    id: id,
    ownerId: ownerId,
    name: name,
    startedAt: startedAt,
    points: points ?? this.points,
    status: status ?? this.status,
    endedAt: endedAt ?? this.endedAt,
  );

  Map<String, Object?> toJson() => {
    'ownerId': ownerId,
    'name': name,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'endedAt': endedAt?.millisecondsSinceEpoch,
    'status': status,
    'points': {
      for (var i = 0; i < points.length; i++)
        i.toString().padLeft(8, '0'): points[i].toJson(),
    },
  };

  static BreadcrumbTrip? parse(String id, Object? raw) {
    if (raw is! Map ||
        raw['ownerId'] is! String ||
        raw['name'] is! String ||
        raw['startedAt'] is! num) {
      return null;
    }
    final start = raw['startedAt'] as num;
    final end = raw['endedAt'];
    if (!start.isFinite ||
        start < 0 ||
        start > 8640000000000000 ||
        (end != null &&
            (end is! num ||
                !end.isFinite ||
                end < 0 ||
                end > 8640000000000000))) {
      return null;
    }
    final rawPoints = raw['points'];
    final values = rawPoints is Map ? rawPoints.values : const <Object>[];
    final points =
        values.map(BreadcrumbPoint.parse).whereType<BreadcrumbPoint>().toList()
          ..sort((a, b) => a.time.compareTo(b.time));
    return BreadcrumbTrip(
      id: id,
      ownerId: raw['ownerId'] as String,
      name: raw['name'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(start.toInt()),
      endedAt: end is num
          ? DateTime.fromMillisecondsSinceEpoch(end.toInt())
          : null,
      status: raw['status'] == 'recording'
          ? 'recording'
          : raw['status'] == 'completed'
          ? 'completed'
          : 'interrupted',
      points: List.unmodifiable(points),
    );
  }
}

/// Ignore duplicate notifications, inaccurate fixes and small GPS jitter.
/// A stationary fix every 30 seconds keeps freshness truthful.
bool shouldRecordBreadcrumb(
  BreadcrumbPoint? previous,
  BreadcrumbPoint next,
  DateTime now,
) {
  if (BreadcrumbPoint.parse(next.toJson()) == null ||
      next.accuracy > 50 ||
      now.difference(next.time) > const Duration(seconds: 45) ||
      next.time.difference(now) > const Duration(seconds: 30)) {
    return false;
  }
  if (previous == null) return true;
  final elapsed = next.time.difference(previous.time);
  if (elapsed <= Duration.zero) return false;
  final distance = Geolocator.distanceBetween(
    previous.latitude,
    previous.longitude,
    next.latitude,
    next.longitude,
  );
  return elapsed >= const Duration(seconds: 30) ||
      (elapsed >= const Duration(seconds: 5) && distance >= 5);
}
