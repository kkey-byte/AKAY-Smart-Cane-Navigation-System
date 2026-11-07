import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_plan.dart';

/// Voice-only progress. Never changes a route, UI step, or arrival decision.
class NavigationVoiceGuidance {
  NavigationVoiceGuidance({required this.speak, required this.stopSpeech});
  final Future<bool> Function(String text) speak;
  final Future<void> Function() stopSpeech;
  static final _locations = Expando<LatLng>('voice maneuver locations');
  static void attachLocation(RouteTurnInstruction step, LatLng? location) {
    if (location != null) _locations[step] = location;
  }

  static LatLng? locationOf(RouteTurnInstruction step) => _locations[step];

  RoutePlanResult? _route;
  final _spoken = <String>{};
  final _pending = <String>{};
  final _cues = <({RouteTurnInstruction step, double offset})>[];
  double _progress = 0;
  int _generation = 0;
  bool enabled = true;
  bool _arrived = false;

  void start(RoutePlanResult route) {
    _generation++;
    _route = route;
    _progress = 0;
    _arrived = false;
    _spoken.clear();
    _pending.clear();
    _cues.clear();
    double minimum = 0;
    for (final step in route.turnInstructions) {
      final location = locationOf(step);
      if (location == null || step.maneuverType == 'arrive') continue;
      final projection = _project(location, minimum: minimum);
      if (projection == null || projection.distance > 30) continue;
      minimum = projection.offset;
      _cues.add((step: step, offset: minimum));
    }
  }

  void update({
    required LatLng position,
    required DateTime time,
    required double accuracy,
    required DateTime now,
  }) {
    if (_route == null ||
        _arrived ||
        !accuracy.isFinite ||
        accuracy < 0 ||
        accuracy > 50 ||
        !position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180 ||
        now.difference(time) > const Duration(seconds: 45) ||
        time.difference(now) > const Duration(seconds: 30)) {
      return;
    }
    final projection = _project(position);
    if (projection == null || projection.distance > math.max(25, accuracy)) {
      return;
    }
    _progress = math.max(_progress, projection.offset);
    if (!enabled) return;
    for (var i = 0; i < _cues.length; i++) {
      final cue = _cues[i];
      final remaining = cue.offset - _progress;
      if (remaining < -20 || cue.step.instruction.trim().isEmpty) continue;
      if (remaining <= 15) {
        unawaited(_announce('$i:at', cue.step.instruction));
      } else {
        if (remaining <= 50 && !_spoken.contains('$i:at')) {
          final meters = (remaining / 10).round() * 10;
          unawaited(
            _announce('$i:near', 'In $meters meters, ${cue.step.instruction}'),
          );
        }
        break;
      }
    }
  }

  Future<bool> _announce(String key, String text) async {
    if (_spoken.contains(key)) return true;
    if (!_pending.add(key)) return false;
    final generation = _generation;
    try {
      if (await speak(text) && generation == _generation) {
        _spoken.add(key);
        return true;
      }
    } catch (_) {
      // Playback failure must not escape into GPS/navigation listeners.
    } finally {
      if (generation == _generation) _pending.remove(key);
    }
    return false;
  }

  Future<void> arrived() async {
    if (_arrived || _route == null) return;
    _arrived = true;
    final generation = _generation;
    if (enabled &&
        !await _announce('arrival', 'Arrived at destination') &&
        enabled &&
        generation == _generation) {
      // Arrival has no later step/GPS event to retry a transient engine failure.
      await _announce('arrival', 'Arrived at destination');
    }
  }

  Future<void> stop() async {
    _generation++;
    _route = null;
    _pending.clear();
    _spoken.clear();
    await stopSpeech();
  }

  ({double offset, double distance})? _project(
    LatLng point, {
    double minimum = 0,
  }) {
    final line = _route?.polylinePoints ?? const <LatLng>[];
    ({double offset, double distance})? best;
    double offset = 0;
    for (var i = 1; i < line.length; i++) {
      final a = line[i - 1], b = line[i];
      final length = Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
      final scale = math.cos(point.latitude * math.pi / 180);
      final dx = (b.longitude - a.longitude) * scale,
          dy = b.latitude - a.latitude;
      final denominator = dx * dx + dy * dy;
      final t = denominator == 0
          ? 0.0
          : (((point.longitude - a.longitude) * scale * dx +
                        (point.latitude - a.latitude) * dy) /
                    denominator)
                .clamp(0.0, 1.0);
      final along = offset + length * t;
      if (along >= minimum - .1) {
        final distance = Geolocator.distanceBetween(
          point.latitude,
          point.longitude,
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
        if (best == null || distance < best.distance) {
          best = (offset: along, distance: distance);
        }
      }
      offset += length;
    }
    return best;
  }
}
