import 'dart:async';
import 'package:app_mobile/models/breadcrumb_trip.dart';
import 'package:app_mobile/services/breadcrumb_recorder.dart';
import 'package:app_mobile/services/breadcrumb_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryRepository implements BreadcrumbRepository {
  bool offline = false;
  Completer<void>? gate;
  final saved = <String, BreadcrumbTrip>{};
  @override
  Future<void> save(BreadcrumbTrip trip) async {
    await gate?.future;
    if (offline) throw StateError('offline');
    saved['${trip.ownerId}/${trip.id}'] = trip;
  }

  @override
  Stream<List<BreadcrumbTrip>> watchTrips(String ownerId, {int limit = 100}) =>
      Stream.value(
        saved.values.where((trip) => trip.ownerId == ownerId).toList(),
      );
}

class WritablePreferences extends Fake implements SharedPreferences {
  final values = <String, String>{};
  bool allowWrites = true;
  @override
  String? getString(String key) => values[key];
  @override
  Future<bool> setString(String key, String value) async {
    if (!allowWrites) return false;
    values[key] = value;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 9, 29, 12);
  BreadcrumbPoint point(double lat, int seconds, {double accuracy = 8}) =>
      BreadcrumbPoint(
        lat,
        125.68,
        now.add(Duration(seconds: seconds)),
        accuracy,
      );

  test(
    'failed device persistence is visible and retries before cloud acknowledgement',
    () async {
      final preferences = WritablePreferences();
      final repository = MemoryRepository();
      final recorder = BreadcrumbRecorder(repository, preferences);
      await recorder.openAccount('owner');
      preferences.allowWrites = false;
      await expectLater(
        recorder.start('Trip', point(7.3, 0)),
        throwsStateError,
      );
      expect(recorder.storageError, isNotNull);
      await recorder.sync();
      expect(repository.saved, isEmpty);
      expect(recorder.hasPending, isTrue);
      preferences.allowWrites = true;
      await recorder.sync();
      expect(recorder.storageError, isNull);
      expect(recorder.hasPending, isFalse);
      final restarted = BreadcrumbRecorder(repository, preferences);
      await restarted.openAccount('owner');
      expect(restarted.trips.single.points.first.time, now);
    },
  );

  test(
    'unreadable pending data is preserved even when pause is requested',
    () async {
      final preferences = WritablePreferences();
      const corrupt = '{invalid saved track data';
      preferences.values['akay_breadcrumbs_owner'] = corrupt;
      final recorder = BreadcrumbRecorder(MemoryRepository(), preferences);
      await recorder.openAccount('owner');
      expect(recorder.storageError, isNotNull);
      await expectLater(recorder.stop(pauseRecording: true), throwsStateError);
      await recorder.sync();
      expect(preferences.values['akay_breadcrumbs_owner'], corrupt);
    },
  );

  test(
    'retention is opt-in and never removes an unacknowledged trip',
    () async {
      SharedPreferences.setMockInitialValues({});
      final recorder = BreadcrumbRecorder(
        MemoryRepository(),
        await SharedPreferences.getInstance(),
      );
      await recorder.openAccount('owner');
      await recorder.start('Trip', point(7.3, 0));
      await recorder.stop();
      final future = DateTime.now().add(const Duration(days: 20));
      await recorder.applyRetention(days: 1, now: future);
      expect(recorder.trips, hasLength(1));
      await recorder.sync();
      await recorder.applyRetention(now: future);
      expect(recorder.trips, hasLength(1));
      await recorder.applyRetention(days: 1, now: future);
      expect(recorder.trips, isEmpty);
    },
  );

  test(
    'confirmed account removal erases the durable queue and cannot restore it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = MemoryRepository()..offline = true;
      final recorder = BreadcrumbRecorder(repository, preferences);
      await recorder.openAccount('removed-owner');
      await recorder.start('Trip', point(7.3, 0));
      await recorder.stop();
      await recorder.eraseLocalAccountHistory();
      expect(recorder.hasPending, isFalse);
      expect(recorder.trips, isEmpty);
      expect(
        preferences.containsKey('akay_breadcrumbs_removed-owner'),
        isFalse,
      );
      final restarted = BreadcrumbRecorder(repository, preferences);
      await restarted.openAccount('removed-owner');
      expect(restarted.trips, isEmpty);
    },
  );

  test(
    'records movement, rejects jitter, stale fixes and invalid coordinates',
    () {
      final first = point(7.30, 0);
      expect(shouldRecordBreadcrumb(null, first, now), isTrue);
      expect(shouldRecordBreadcrumb(first, first, now), isFalse);
      expect(shouldRecordBreadcrumb(first, point(7.300001, 3), now), isFalse);
      expect(shouldRecordBreadcrumb(first, point(7.3002, 5), now), isTrue);
      expect(
        shouldRecordBreadcrumb(first, point(7.301, 3, accuracy: 100), now),
        isFalse,
      );
      expect(shouldRecordBreadcrumb(null, point(91, 0), now), isFalse);
      expect(shouldRecordBreadcrumb(null, point(7.3, -60), now), isFalse);
      expect(
        shouldRecordBreadcrumb(
          first,
          point(7.3, 30),
          now.add(const Duration(seconds: 30)),
        ),
        isFalse,
      );
    },
  );

  test(
    'offline trip survives restart and syncs, while account histories stay isolated',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = MemoryRepository()..offline = true;
      final recorder = BreadcrumbRecorder(repository, preferences);
      await recorder.openAccount('navigator-a');
      await recorder.start('Walk home', point(7.3, 0));
      await recorder.start('Repeated tap', point(7.3, 0));
      expect(recorder.trips, hasLength(1));
      await recorder.record(
        point(7.3002, 5),
        now.add(const Duration(seconds: 5)),
      );
      await recorder.record(
        point(7.3003, 10),
        now.add(const Duration(seconds: 10)),
      );
      await recorder.sync();
      expect(recorder.hasPending, isTrue);
      expect(recorder.syncError, isNotNull);
      final restored = BreadcrumbRecorder(repository, preferences);
      await restored.openAccount('navigator-a');
      expect(restored.active, isNull);
      expect(restored.trips.single.status, 'interrupted');
      expect(restored.trips.single.points, hasLength(3));
      repository.offline = false;
      await restored.sync();
      expect(restored.hasPending, isFalse);
      expect(repository.saved.values.single.points, hasLength(3));
      await restored.openAccount('navigator-b');
      expect(restored.trips, isEmpty);
      await restored.openAccount('navigator-a');
      expect(restored.trips, hasLength(1));
    },
  );

  test(
    'completed trips retain ordered coordinates and are never shown as live',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = MemoryRepository();
      final recorder = BreadcrumbRecorder(
        repository,
        await SharedPreferences.getInstance(),
      );
      await recorder.openAccount('owner');
      await recorder.start('Trip', point(7.3, 0));
      await recorder.record(
        point(7.3002, 5),
        now.add(const Duration(seconds: 5)),
      );
      await recorder.record(
        point(7.3003, 10),
        now.add(const Duration(seconds: 10)),
      );
      expect(
        recorder.active!.isFresh(now.add(const Duration(seconds: 11))),
        isTrue,
      );
      expect(
        recorder.active!.isFresh(now.add(const Duration(minutes: 2))),
        isFalse,
      );
      await recorder.stop();
      await recorder.sync();
      final saved = repository.saved.values.single;
      expect(saved.isFresh(now), isFalse);
      final parsed = BreadcrumbTrip.parse(saved.id, saved.toJson())!;
      expect(parsed.status, 'completed');
      expect(parsed.points.last.latitude, 7.3003);
      expect(parsed.ownerId, 'owner');
      expect(BreadcrumbPoint.parse({'latitude': double.nan}), isNull);
    },
  );

  test(
    'a GPS fix arriving during upload remains queued until acknowledged',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = MemoryRepository()..gate = Completer<void>();
      final recorder = BreadcrumbRecorder(
        repository,
        await SharedPreferences.getInstance(),
      );
      await recorder.openAccount('owner');
      await recorder.start('Trip', point(7.3, 0));
      final upload = recorder.sync();
      await recorder.record(
        point(7.3002, 5),
        now.add(const Duration(seconds: 5)),
      );
      await recorder.record(
        point(7.3003, 10),
        now.add(const Duration(seconds: 10)),
      );
      repository.gate!.complete();
      await upload;
      expect(recorder.hasPending, isTrue);
      expect(repository.saved.values.single.points, hasLength(1));
      repository.gate = null;
      await recorder.sync();
      expect(recorder.hasPending, isFalse);
      expect(repository.saved.values.single.points, hasLength(3));
    },
  );
}
