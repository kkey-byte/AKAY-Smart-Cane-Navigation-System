import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/breadcrumb_trip.dart';
import 'breadcrumb_recorder.dart';

/// Session-owned recording. Navigation destinations never control this owner.
class ContinuousBreadcrumbTracker extends ChangeNotifier {
  ContinuousBreadcrumbTracker({
    required this.recorder,
    required this.eligibleOwner,
    required this.startLocation,
    required this.backgroundRecording,
    required this.currentPoint,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final BreadcrumbRecorder recorder;
  final String? Function() eligibleOwner;
  final Future<void> Function() startLocation;
  final Future<void> Function(bool) backgroundRecording;
  final BreadcrumbPoint? Function() currentPoint;
  final DateTime Function() clock;
  Future<void> _queue = Future.value();
  String? _sessionOwner;
  bool _paused = false;
  int _generation = 0;
  String? error;
  bool get requested => eligibleOwner() != null && !_paused;

  Future<void> _enqueue(Future<void> Function() action) {
    return _queue = _queue.then((_) => action()).catchError((Object _) {
      error =
          'Track recording is unavailable. Check location permission and GPS.';
      notifyListeners();
    });
  }

  /// Called on session changes, app resume and recovery, never per page.
  Future<void> reconcile() {
    final owner = eligibleOwner();
    final generation = ++_generation;
    return _enqueue(() async {
      if (generation != _generation) return;
      if (_sessionOwner != owner) {
        await recorder.stop(status: 'interrupted');
        await backgroundRecording(false);
        await recorder.openAccount(owner);
        _sessionOwner = owner;
        _paused = false;
      }
      if (owner == null || _paused) return;
      await startLocation();
      if (eligibleOwner() != owner || generation != _generation || _paused) {
        return;
      }
      await backgroundRecording(true);
      if (eligibleOwner() != owner || generation != _generation || _paused) {
        await backgroundRecording(false);
        return;
      }
      await _recordCurrent(owner);
    });
  }

  Future<void> onLocation() => _enqueue(() async {
    final owner = eligibleOwner();
    if (owner == null || owner != _sessionOwner || _paused) return;
    await _recordCurrent(owner);
  });

  Future<void> _recordCurrent(String owner) async {
    final point = currentPoint();
    final now = clock();
    if (point == null || !shouldRecordBreadcrumb(null, point, now)) {
      error =
          'Waiting for a fresh, accurate GPS location. Check GPS and location access.';
      notifyListeners();
      return;
    }
    if (eligibleOwner() != owner || recorder.ownerId != owner || _paused) {
      return;
    }
    final active = recorder.active;
    if (active != null && !point.time.isAfter(active.points.last.time)) {
      return;
    }
    if (active != null &&
        (active.points.length >= 500 ||
            point.time.difference(active.startedAt) >=
                const Duration(hours: 1) ||
            !_sameDay(point.time, active.startedAt))) {
      await recorder.stop();
    }
    if (eligibleOwner() != owner || recorder.ownerId != owner || _paused) {
      return;
    }
    if (recorder.active == null) {
      await recorder.start('Daily track ${_date(point.time)}', point);
    } else {
      await recorder.record(point, now);
    }
    error = null;
    notifyListeners();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  static String _date(DateTime time) =>
      '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';

  Future<void> resume() {
    _paused = false;
    return reconcile();
  }

  /// Explicit user pause or logout, rather than route completion.
  Future<void> pause() {
    _paused = true;
    _generation++;
    return _enqueue(() async {
      await recorder.stop();
      await backgroundRecording(false);
      notifyListeners();
    });
  }
}
