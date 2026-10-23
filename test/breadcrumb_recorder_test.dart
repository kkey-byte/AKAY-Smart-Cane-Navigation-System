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
    'records movement, rejects jitter, stale fixes and invalid coordinates',
    () {
      final first = point(7.30, 0);
      expect(shouldRecordBreadcrumb(null, first, now), isTrue);
      expect(shouldRecordBreadcrumb(first, first, now), isFalse);
      expect(shouldRecordBreadcrumb(first, point(7.300001, 3), now), isFalse);
      expect(shouldRecordBreadcrumb(first, point(7.301, 5), now), isTrue);
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
        isTrue,
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
        point(7.301, 5),
        now.add(const Duration(seconds: 5)),
      );
      await recorder.sync();
      expect(recorder.hasPending, isTrue);
      expect(recorder.syncError, isNotNull);
      final restored = BreadcrumbRecorder(repository, preferences);
      await restored.openAccount('navigator-a');
      expect(restored.active, isNull);
      expect(restored.trips.single.status, 'interrupted');
      expect(restored.trips.single.points, hasLength(2));
      repository.offline = false;
      await restored.sync();
      expect(restored.hasPending, isFalse);
      expect(repository.saved.values.single.points, hasLength(2));
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
        point(7.301, 5),
        now.add(const Duration(seconds: 5)),
      );
      expect(
        recorder.active!.isFresh(now.add(const Duration(seconds: 6))),
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
      expect(parsed.points.last.latitude, 7.301);
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
        point(7.301, 5),
        now.add(const Duration(seconds: 5)),
      );
      repository.gate!.complete();
      await upload;
      expect(recorder.hasPending, isTrue);
      expect(repository.saved.values.single.points, hasLength(1));
      repository.gate = null;
      await recorder.sync();
      expect(recorder.hasPending, isFalse);
      expect(repository.saved.values.single.points, hasLength(2));
    },
  );
}
