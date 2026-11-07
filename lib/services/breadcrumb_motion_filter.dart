import '../models/breadcrumb_trip.dart';
import 'package:geolocator/geolocator.dart';

/// Conservative GPS-only movement detection. Accuracy is an estimate, not a
/// guaranteed bound. Two consecutive departures are required after a stop;
/// isolated jumps never become vertices. No minimum walking speed is imposed.
class BreadcrumbMotionFilter {
  BreadcrumbPoint? _anchor;
  BreadcrumbPoint? _candidate;
  BreadcrumbPoint? _observed;
  bool _moving = false;
  BreadcrumbPoint? get anchor => _anchor;

  void reset(BreadcrumbPoint first) {
    _anchor = first;
    _observed = first;
    _candidate = null;
    _moving = false;
  }

  List<BreadcrumbPoint> add(BreadcrumbPoint point, DateTime now) {
    if (!shouldRecordBreadcrumb(null, point, now)) return [];
    final anchor = _anchor;
    final observed = _observed;
    if (anchor == null || observed == null) {
      reset(point);
      return [point];
    }
    if (!point.time.isAfter(observed.time)) return [];
    final seconds = point.time.difference(observed.time).inMilliseconds / 1000;
    final step = Geolocator.distanceBetween(
      observed.latitude,
      observed.longitude,
      point.latitude,
      point.longitude,
    );
    // Reject implausible jumps without moving the reference to the outlier.
    if (step > 12 * seconds + observed.accuracy + point.accuracy) {
      _candidate = null;
      return [];
    }
    _observed = point;
    if (!shouldRecordBreadcrumb(anchor, point, now)) {
      _candidate = null;
      if (point.time.difference(anchor.time) >= const Duration(seconds: 30)) {
        _moving = false;
      }
      return [];
    }
    if (_moving) {
      _anchor = point;
      return [point];
    }
    final candidate = _candidate;
    if (candidate == null ||
        point.time.difference(candidate.time) > const Duration(seconds: 30)) {
      _candidate = point;
      return [];
    }
    if (point.time.difference(candidate.time) < const Duration(seconds: 5)) {
      return [];
    }
    // Both departures must agree spatially; an opposite-side drift does not
    // confirm the pending departure.
    final separation = Geolocator.distanceBetween(
      candidate.latitude,
      candidate.longitude,
      point.latitude,
      point.longitude,
    );
    final departure = Geolocator.distanceBetween(
      anchor.latitude,
      anchor.longitude,
      point.latitude,
      point.longitude,
    );
    if (separation > departure) {
      _candidate = point;
      return [];
    }
    _moving = true;
    _candidate = null;
    _anchor = point;
    return [candidate, point];
  }
}
