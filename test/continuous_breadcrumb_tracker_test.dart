import 'dart:async';
import 'package:app_mobile/models/breadcrumb_trip.dart';
import 'package:app_mobile/models/route_plan.dart';
import 'package:app_mobile/services/breadcrumb_recorder.dart';
import 'package:app_mobile/services/continuous_breadcrumb_tracker.dart';
import 'package:app_mobile/services/route_timeline_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'breadcrumb_recorder_test.dart' show MemoryRepository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BreadcrumbRecorder recorder;
  late ContinuousBreadcrumbTracker tracker;
  late MemoryRepository repository;
  String? owner;
  var now = DateTime(2026, 10, 22, 12);
  BreadcrumbPoint? fix;
  final background = <bool>[];
  var starts = 0;
  final published = <BreadcrumbPoint>[];
  Completer<void>? publication;
  Completer<void>? startup;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = MemoryRepository();
    recorder = BreadcrumbRecorder(
      repository,
      await SharedPreferences.getInstance(),
    );
    now = DateTime(2026, 10, 22, 12);
    owner = 'synthetic-navigator';
    fix = BreadcrumbPoint(7.3, 125.68, now, 8);
    background.clear();
    starts = 0;
    published.clear();
    publication = null;
    startup = null;
    tracker = ContinuousBreadcrumbTracker(
      recorder: recorder,
      eligibleOwner: () => owner,
      currentPoint: () => fix,
      clock: () => now,
      publishLocation: (point) async {
        published.add(point);
        await publication?.future;
      },
      startLocation: () async {
        starts++;
        await startup?.future;
      },
      backgroundRecording: (enabled) async {
        background.add(enabled);
      },
    );
  });

  Future<void> move({
    Duration elapsed = const Duration(seconds: 5),
    double lat = 7.301,
  }) async {
    now = now.add(elapsed);
    fix = BreadcrumbPoint(lat, 125.68, now, 8);
    await tracker.onLocation();
  }

  test(
    'live publication continues when history filters small movements',
    () async {
      await tracker.reconcile();
      await move(elapsed: const Duration(seconds: 2), lat: 7.300001);
      expect(published, hasLength(2));
      expect(recorder.active!.points, hasLength(1));
      await tracker.pause();
      await move();
      expect(published, hasLength(2));
    },
  );

  test('pending cloud publication does not block recording or pause', () async {
    publication = Completer<void>();
    await tracker.reconcile();
    await move();
    expect(recorder.active!.points, hasLength(2));
    await tracker.pause();
    expect(recorder.active, isNull);
    publication!.complete();
  });

  test(
    'starts without a route and continues after arrival and route reset',
    () async {
      await tracker.reconcile();
      expect(starts, 1);
      expect(background.last, isTrue);
      expect(recorder.active, isNotNull);
      final id = recorder.activeId;
      final navigation = RouteTimelineTracker.instance;
      navigation.startTracking(
        const MapPlace(
          id: 'synthetic',
          name: 'Synthetic destination',
          address: '',
          latitude: 7.301,
          longitude: 125.68,
        ),
      );
      navigation.markDestinationArrived();
      await move();
      navigation.reset();
      await move(lat: 7.302);
      expect(recorder.activeId, id);
      expect(recorder.active!.points, hasLength(3));
      await recorder.sync();
      expect(repository.saved.values.single.points, hasLength(3));
    },
  );

  test(
    'rolls hourly and at midnight without losing the next location',
    () async {
      now = DateTime(2026, 10, 22, 22, 30);
      fix = BreadcrumbPoint(7.3, 125.68, now, 8);
      await tracker.reconcile();
      await move(elapsed: const Duration(hours: 1));
      expect(recorder.trips, hasLength(2));
      expect(recorder.active, isNotNull);
      await move(elapsed: const Duration(minutes: 30), lat: 7.302);
      expect(recorder.trips, hasLength(3));
      expect(recorder.active!.name, contains('2026-10-23'));
      expect(recorder.trips.where((trip) => trip.isRecording), hasLength(1));
    },
  );

  test(
    'explicit pause survives recovery ticks and resume restarts recording',
    () async {
      await tracker.reconcile();
      await tracker.pause();
      final count = starts;
      await tracker.reconcile();
      await move();
      expect(starts, count);
      expect(recorder.active, isNull);
      expect(tracker.requested, isFalse);
      await tracker.resume();
      expect(recorder.active, isNotNull);
      expect(tracker.requested, isTrue);
    },
  );

  test(
    'logout cancels in-flight startup and caregivers never record',
    () async {
      startup = Completer<void>();
      final pending = tracker.reconcile();
      await Future<void>.delayed(Duration.zero);
      owner = null;
      final logout = tracker.reconcile();
      startup!.complete();
      await pending;
      await logout;
      expect(recorder.ownerId, isNull);
      expect(recorder.active, isNull);
      expect(background.contains(true), isFalse);
      await tracker.reconcile();
      expect(starts, 1);
    },
  );

  test(
    'new account cannot receive previous account points or cloud acknowledgments',
    () async {
      await tracker.reconcile();
      repository.gate = Completer<void>();
      final oldUpload = recorder.sync();
      owner = 'synthetic-second';
      fix = null;
      await tracker.reconcile();
      expect(recorder.ownerId, owner);
      expect(recorder.trips, isEmpty);
      await move();
      expect(recorder.active!.ownerId, owner);
      repository.gate!.complete();
      await oldUpload;
      expect(recorder.hasPending, isTrue);
      repository.gate = null;
      await recorder.sync();
      expect(recorder.hasPending, isFalse);
      expect(
        repository.saved.values.map((trip) => trip.ownerId).toSet(),
        containsAll(['synthetic-navigator', 'synthetic-second']),
      );
    },
  );

  test(
    'poor GPS fixes do not create tracks, and a later fix recovers',
    () async {
      fix = BreadcrumbPoint(7.3, 125.68, now, 90);
      await tracker.reconcile();
      expect(recorder.active, isNull);
      expect(tracker.error, isNotNull);
      await move();
      expect(recorder.active, isNotNull);
      expect(tracker.error, isNull);
    },
  );

  test(
    'a long offline day rolls bounded segments and uploads every point later',
    () async {
      repository.offline = true;
      await tracker.reconcile();
      for (var i = 1; i <= 501; i++) {
        await move(lat: 7.3 + i * .0001);
      }
      expect(recorder.trips, hasLength(2));
      expect(recorder.trips.every((trip) => trip.points.length <= 500), isTrue);
      await recorder.sync();
      expect(recorder.hasPending, isTrue);
      repository.offline = false;
      await recorder.sync();
      expect(
        repository.saved.values.fold<int>(
          0,
          (sum, trip) => sum + trip.points.length,
        ),
        502,
      );
      expect(recorder.hasPending, isFalse);
      expect(recorder.active, isNotNull);
    },
  );
}
