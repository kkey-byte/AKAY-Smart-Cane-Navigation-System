import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/breadcrumb_trip.dart';
import 'breadcrumb_repository.dart';
import 'breadcrumb_motion_filter.dart';

/// Account-scoped durable outbox. Cloud failures never discard recorded points.
class BreadcrumbRecorder extends ChangeNotifier {
  BreadcrumbRecorder(this.repository, this.preferences);
  final BreadcrumbRepository repository;
  final SharedPreferences preferences;
  final Map<String, BreadcrumbTrip> _trips = {};
  final Set<String> _pending = {};
  final _motion = BreadcrumbMotionFilter();
  Future<void> _diskQueue = Future.value();
  Future<void>? _upload;
  String? ownerId;
  String? activeId;
  String? syncError;
  String? storageError;
  int _generation = 0;
  BreadcrumbTrip? get active => _trips[activeId];
  bool get hasPending => _pending.isNotEmpty;
  List<BreadcrumbTrip> get trips =>
      _trips.values.toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  Future<void> openAccount(String? uid) async {
    if (ownerId == uid) return;
    if (active != null) await stop(status: 'interrupted');
    await _diskQueue;
    _generation++;
    _upload = null;
    ownerId = uid;
    activeId = null;
    _trips.clear();
    _pending.clear();
    syncError = null;
    storageError = null;
    if (uid != null) {
      final raw = preferences.getString('akay_breadcrumbs_$uid');
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw) as Map;
          final saved = decoded['trips'] as Map;
          for (final entry in saved.entries) {
            var trip = BreadcrumbTrip.parse(entry.key.toString(), entry.value);
            if (trip == null || trip.ownerId != uid) continue;
            if (trip.isRecording) {
              trip = trip.copyWith(
                status: 'interrupted',
                endedAt: trip.points.lastOrNull?.time ?? trip.startedAt,
              );
              _pending.add(trip.id);
            }
            _trips[trip.id] = trip;
          }
          _pending.addAll((decoded['pending'] as List).whereType<String>());
        } catch (_) {
          storageError =
              'Saved track data could not be read. Please keep this device data for recovery.';
        }
      }
    }
    notifyListeners();
    if (uid != null && storageError == null) await _persist();
  }

  Future<void> start(String name, BreadcrumbPoint first) async {
    if (active != null) return;
    final uid = ownerId;
    if (uid == null) throw StateError('Sign in to record a track.');
    if (storageError != null) throw StateError(storageError!);
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    _trips[id] = BreadcrumbTrip(
      id: id,
      ownerId: uid,
      name: name,
      startedAt: first.time,
      points: [first],
    );
    activeId = id;
    _motion.reset(first);
    _pending.add(id);
    await _persist();
    notifyListeners();
  }

  Future<void> record(BreadcrumbPoint point, DateTime now) async {
    final trip = active;
    if (trip == null ||
        !shouldRecordBreadcrumb(null, point, now) ||
        !point.time.isAfter(trip.points.last.time)) {
      return;
    }
    final anchor = _motion.anchor;
    final movement = _motion.add(point, now);
    if (movement.isEmpty) {
      if (point.time.difference(trip.points.last.time) <
          const Duration(seconds: 30)) {
        return;
      }
      // Aggregate freshness at a fixed endpoint, never append stationary drift.
      // Keep the anchor's accuracy: the new fix describes another coordinate.
      final last = trip.points.last;
      _trips[trip.id] = trip.copyWith(
        points: [
          ...trip.points.take(trip.points.length - 1),
          BreadcrumbPoint(
            last.latitude,
            last.longitude,
            point.time,
            last.accuracy,
          ),
        ],
      );
    } else {
      // Pending confirmation may precede a freshness-only endpoint update.
      final points = trip.points.toList();
      if (!movement.first.time.isAfter(points.last.time)) {
        points[points.length - 1] = anchor!;
      }
      // Preserve the existing 500-vertex bound if confirmation lands at 499.
      final remaining = 500 - points.length;
      _trips[trip.id] = trip.copyWith(
        points: [
          ...points,
          ...movement.skip(
            movement.length > remaining ? movement.length - remaining : 0,
          ),
        ],
      );
    }
    _pending.add(trip.id);
    await _persist();
    notifyListeners();
  }

  Future<void> stop({String status = 'completed'}) async {
    final trip = active;
    if (trip == null) return;
    _trips[trip.id] = trip.copyWith(status: status, endedAt: DateTime.now());
    activeId = null;
    _pending.add(trip.id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() {
    final uid = ownerId;
    if (uid == null) return Future.value();
    final value = jsonEncode({
      'trips': {for (final trip in _trips.values) trip.id: trip.toJson()},
      'pending': _pending.toList(),
    });
    final write = _diskQueue.then((_) async {
      final saved = await preferences.setString('akay_breadcrumbs_$uid', value);
      if (!saved) throw StateError('Device storage rejected the track.');
    });
    _diskQueue = write.catchError((Object error) {
      storageError = 'Unable to save tracks on this device: $error';
      notifyListeners();
    });
    return _diskQueue;
  }

  Future<void> sync() {
    if (_upload != null) return _upload!;
    final generation = _generation;
    final upload = _sync(generation);
    _upload = upload;
    return upload.whenComplete(() {
      if (identical(_upload, upload)) _upload = null;
    });
  }

  Future<void> _sync(int generation) async {
    for (final id in _pending.toList()) {
      if (generation != _generation) return;
      final trip = _trips[id];
      if (trip == null) continue;
      try {
        // Firebase acknowledges writes after reconnecting. Keep one in flight
        // rather than enqueueing the same offline payload on every retry tick.
        await repository.save(trip);
        if (generation != _generation) return;
        // A newer GPS fix arrived during the write: keep it queued.
        if (identical(_trips[id], trip)) _pending.remove(id);
        syncError = null;
        await _persist();
      } catch (_) {
        if (generation != _generation) return;
        syncError =
            'Tracks are saved on this device. Cloud sync is unavailable; retrying automatically.';
        break;
      }
    }
    notifyListeners();
  }
}
