import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/breadcrumb_trip.dart';
import 'breadcrumb_repository.dart';
import 'breadcrumb_motion_filter.dart';
import 'secure_api.dart';

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
  bool recordingPaused = false;
  bool _cacheUnreadable = false;
  int _generation = 0;
  BreadcrumbTrip? get active => _trips[activeId];
  bool get hasPending => _pending.isNotEmpty;
  int get pendingCount => _pending.length;
  bool get isSyncing => _upload != null;
  bool isPending(String id) => _pending.contains(id);
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
    recordingPaused = false;
    _cacheUnreadable = false;
    if (uid != null) {
      final raw = preferences.getString('akay_breadcrumbs_$uid');
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw) as Map;
          recordingPaused = decoded['recordingPaused'] == true;
          final saved = decoded['trips'] as Map;
          for (final entry in saved.entries) {
            var trip = BreadcrumbTrip.parse(entry.key.toString(), entry.value);
            if (trip == null || trip.ownerId != uid) {
              throw const FormatException('Invalid saved track');
            }
            if (trip.isRecording) {
              trip = trip.copyWith(
                status: 'interrupted',
                endedAt:
                    trip.lastSampledAt ??
                    trip.points.lastOrNull?.time ??
                    trip.startedAt,
              );
              _pending.add(trip.id);
            }
            _trips[trip.id] = trip;
          }
          _pending.addAll((decoded['pending'] as List).whereType<String>());
          if (_pending.any((id) => !_trips.containsKey(id))) {
            throw const FormatException('Missing pending track');
          }
        } catch (_) {
          _cacheUnreadable = true;
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
        !point.time.isAfter(trip.lastSampledAt ?? trip.points.last.time)) {
      return;
    }
    final movement = _motion.add(point, now);
    if (movement.isEmpty) {
      if (point.time.difference(trip.lastSampledAt ?? trip.points.last.time) <
          const Duration(seconds: 30)) {
        return;
      }
      // Freshness is separate from route geometry. Never relabel the original
      // capture time of an already uploaded stationary endpoint.
      _trips[trip.id] = trip.copyWith(lastSampledAt: point.time);
    } else {
      final points = trip.points.toList();
      // Preserve the existing 500-vertex bound if confirmation lands at 499.
      final remaining = 500 - points.length;
      _trips[trip.id] = trip.copyWith(
        points: [
          ...points,
          ...movement.skip(
            movement.length > remaining ? movement.length - remaining : 0,
          ),
        ],
        lastSampledAt: point.time,
      );
    }
    _pending.add(trip.id);
    await _persist();
    notifyListeners();
  }

  Future<void> stop({
    String status = 'completed',
    DateTime? endedAt,
    bool pauseRecording = false,
  }) async {
    if (pauseRecording) recordingPaused = true;
    final trip = active;
    if (trip == null) {
      if (pauseRecording) await _persist();
      notifyListeners();
      return;
    }
    final lastCapture = trip.lastSampledAt ?? trip.points.last.time;
    final end = endedAt ?? DateTime.now();
    _trips[trip.id] = trip.copyWith(
      status: status,
      endedAt: end.isBefore(lastCapture) ? lastCapture : end,
    );
    activeId = null;
    _pending.add(trip.id);
    await _persist();
    notifyListeners();
  }

  Future<void> setRecordingPaused(bool paused) async {
    recordingPaused = paused;
    await _persist();
    notifyListeners();
  }

  /// Call only after the trusted backend confirms permanent account removal.
  Future<void> eraseLocalAccountHistory() async {
    final uid = ownerId;
    if (uid == null) return;
    final generation = ++_generation;
    _upload = null;
    activeId = null;
    _trips.clear();
    _pending.clear();
    await _diskQueue;
    final removed = await preferences.remove('akay_breadcrumbs_$uid');
    if (!removed) throw StateError('Local history removal failed.');
    if (_generation == generation && ownerId == uid) ownerId = null;
    notifyListeners();
  }

  Future<void> removeLocalTrip(String id) async {
    if (activeId == id) throw StateError('Stop this trip before deleting it.');
    _trips.remove(id);
    _pending.remove(id);
    await _persist();
    notifyListeners();
  }

  /// No cleanup occurs until an explicit retention policy is configured.
  Future<void> applyRetention({int? days, DateTime? now}) async {
    if (days == null || days == 0) return;
    if (days < 0) throw ArgumentError.value(days, 'days');
    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: days));
    final previousCount = _trips.length;
    _trips.removeWhere(
      (id, trip) =>
          !_pending.contains(id) &&
          !trip.isRecording &&
          trip.endedAt != null &&
          trip.endedAt!.isBefore(cutoff),
    );
    if (_trips.length == previousCount) return;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() {
    if (_cacheUnreadable) {
      return Future.error(StateError('Saved track data needs recovery.'));
    }
    final uid = ownerId;
    if (uid == null) return Future.value();
    final value = jsonEncode({
      'recordingPaused': recordingPaused,
      'trips': {for (final trip in _trips.values) trip.id: trip.toJson()},
      'pending': _pending.toList(),
    });
    final generation = _generation;
    final write = _diskQueue.then((_) async {
      final saved = await preferences.setString('akay_breadcrumbs_$uid', value);
      if (!saved) throw StateError('Device storage rejected the track.');
      if (generation == _generation) storageError = null;
    });
    _diskQueue = write.catchError((Object error) {
      if (generation == _generation) {
        storageError = 'Unable to save tracks on this device.';
      }
      notifyListeners();
    });
    return write;
  }

  Future<void> sync() {
    if (_upload != null) return _upload!;
    final generation = _generation;
    final upload = _sync(generation);
    _upload = upload;
    notifyListeners();
    return upload.whenComplete(() {
      if (identical(_upload, upload)) {
        _upload = null;
        notifyListeners();
      }
    });
  }

  Future<void> _sync(int generation) async {
    for (final id in _pending.toList()) {
      if (generation != _generation) return;
      final trip = _trips[id];
      if (trip == null) continue;
      try {
        await _diskQueue;
        if (_cacheUnreadable || generation != _generation) return;
        if (storageError != null) await _persist();
        if (generation != _generation) return;
        // Firebase acknowledges writes after reconnecting. Keep one in flight
        // rather than enqueueing the same offline payload on every retry tick.
        await repository.save(trip);
        if (generation != _generation) return;
        // A newer GPS fix arrived during the write: keep it queued.
        if (identical(_trips[id], trip)) _pending.remove(id);
        syncError = null;
        await _persist();
      } catch (error) {
        if (generation != _generation) return;
        if (kDebugMode) {
          final reason = error is SecureApiException && error.status != null
              ? 'HTTP ${error.status}'
              : 'connection or upload failure';
          debugPrint(
            'Trip history sync unavailable ($reason). Pending data retained.',
          );
        }
        syncError = storageError != null
            ? 'Device save is not confirmed. Keep the app open and retry saving.'
            : 'Tracks are saved on this device. Cloud sync is unavailable; retrying automatically.';
        break;
      }
    }
    if (generation == _generation) {
      const days = int.fromEnvironment('AKAY_TRIP_RETENTION_DAYS');
      if (days > 0) await applyRetention(days: days);
    }
    notifyListeners();
  }
}
