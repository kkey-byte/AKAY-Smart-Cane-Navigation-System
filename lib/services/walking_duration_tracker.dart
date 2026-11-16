import 'package:geolocator/geolocator.dart';
import '../models/breadcrumb_trip.dart';
import 'breadcrumb_motion_filter.dart';

/// GPS-estimated walking time. A refresh or a stationary heartbeat is not a
/// walking interval. Confirmation uses the existing conservative drift filter.
class WalkingDurationTracker {
  final _motion = BreadcrumbMotionFilter();
  final List<BreadcrumbPoint> _pending = [];
  BreadcrumbPoint? _last;
  DateTime? _confirmedThrough;

  void reset(BreadcrumbPoint first) {
    _motion.reset(first);
    _pending
      ..clear()
      ..add(first);
    _last = first;
    _confirmedThrough = null;
  }

  void interrupt() {
    _last = null;
    _pending.clear();
    _confirmedThrough = null;
  }

  Duration add(BreadcrumbPoint point, DateTime now) {
    if (!shouldRecordBreadcrumb(null, point, now)) {
      interrupt();
      return Duration.zero;
    }
    final last = _last;
    if (last == null ||
        point.time.difference(last.time) > const Duration(seconds: 30)) {
      reset(point);
      return Duration.zero;
    }
    if (!point.time.isAfter(last.time)) return Duration.zero;
    _last = point;
    _pending.add(point);
    if (_pending.length > 128) _pending.removeAt(0);
    final accepted = _motion.add(point, now);
    if (accepted.isEmpty) return Duration.zero;
    final since = accepted.length > 1 ? accepted.first.time : _confirmedThrough;
    var duration = Duration.zero;
    if (since != null) {
      for (var i = 1; i < _pending.length; i++) {
        final a = _pending[i - 1], b = _pending[i];
        if (a.time.isBefore(since)) continue;
        final elapsed = b.time.difference(a.time);
        final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
        if (seconds <= 0 || seconds > 30) continue;
        final distance = Geolocator.distanceBetween(
          a.latitude,
          a.longitude,
          b.latitude,
          b.longitude,
        );
        // No fixed timer while stopped; reject vehicle-like intervals and tiny
        // coordinate noise even inside an otherwise confirmed moving segment.
        if (distance >= 0.5 && distance / seconds <= 3.5) duration += elapsed;
      }
    }
    _confirmedThrough = accepted.last.time;
    _pending
      ..clear()
      ..add(point);
    return duration;
  }
}
