import 'package:app_mobile/models/breadcrumb_trip.dart';
import 'package:app_mobile/services/walking_duration_tracker.dart';
import 'package:app_mobile/services/breadcrumb_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'breadcrumb_recorder_test.dart' show MemoryRepository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final start = DateTime(2026, 11, 16, 12);
  BreadcrumbPoint point(double meters, int seconds, {double accuracy = 8}) =>
      BreadcrumbPoint(
        meters / 111195,
        0,
        start.add(Duration(seconds: seconds)),
        accuracy,
      );
  Duration add(WalkingDurationTracker tracker, double meters, int seconds) =>
      tracker.add(point(meters, seconds), point(meters, seconds).time);

  test('stationary refreshes and bounded GPS drift add no walking time', () {
    final tracker = WalkingDurationTracker()..reset(point(0, 0));
    var total = Duration.zero;
    for (var i = 1; i <= 120; i++) {
      total += add(tracker, i.isEven ? 7 : -7, i * 5);
    }
    expect(total, Duration.zero);
  });
  test(
    'only confirmed walking intervals count and standing time is excluded',
    () {
      final tracker = WalkingDurationTracker()..reset(point(0, 0));
      expect(add(tracker, 20, 10), Duration.zero);
      var total = add(tracker, 22, 15);
      expect(total, const Duration(seconds: 5));
      total += add(tracker, 40, 25);
      expect(total, const Duration(seconds: 15));
      for (var t = 30; t <= 120; t += 5) {
        total += add(tracker, 40, t);
      }
      expect(total, const Duration(seconds: 15));
      expect(add(tracker, 60, 130), Duration.zero);
      total += add(tracker, 62, 135);
      expect(total, const Duration(seconds: 20));
    },
  );
  test(
    'slow confirmed walking counts but a jump, vehicle-like motion or a long GPS gap does not',
    () {
      final slow = WalkingDurationTracker()..reset(point(0, 0));
      var total = Duration.zero;
      for (final sample in [
        (6.0, 15),
        (12.0, 30),
        (18.0, 45),
        (20.0, 50),
        (38.0, 70),
      ]) {
        total += add(slow, sample.$1, sample.$2);
      }
      expect(total, greaterThan(Duration.zero));
      final fast = WalkingDurationTracker()..reset(point(0, 0));
      expect(
        add(fast, 40, 5) + add(fast, 80, 10) + add(fast, 120, 15),
        Duration.zero,
      );
      final gap = WalkingDurationTracker()..reset(point(0, 0));
      add(gap, 20, 10);
      expect(add(gap, 22, 15), const Duration(seconds: 5));
      expect(add(gap, 40, 1000), Duration.zero);
      final jump = WalkingDurationTracker()..reset(point(0, 0));
      expect(add(jump, 1000, 5), Duration.zero);
      expect(add(jump, 0, 10), Duration.zero);
    },
  );
  test(
    'invalid fixes interrupt confirmation and duplicate captures cannot add time',
    () {
      final tracker = WalkingDurationTracker()..reset(point(0, 0));
      add(tracker, 20, 10);
      final bad = point(22, 15, accuracy: 90);
      expect(tracker.add(bad, bad.time), Duration.zero);
      expect(add(tracker, 40, 20), Duration.zero);
      expect(add(tracker, 60, 30), Duration.zero);
      expect(add(tracker, 62, 35), const Duration(seconds: 5));
      expect(add(tracker, 62, 35), Duration.zero);
      expect(add(tracker, 60, 30), Duration.zero);
    },
  );
  test(
    'recorder preserves measured time across heartbeats, finish, restart and offline upload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = MemoryRepository()..offline = true;
      final recorder = BreadcrumbRecorder(repository, preferences);
      await recorder.openAccount('synthetic');
      await recorder.start('Point-to-Point: Synthetic', point(0, 0));
      for (final sample in [
        (20.0, 10),
        (22.0, 15),
        (40.0, 25),
        (40.0, 60),
        (40.0, 90),
        (40.0, 120),
      ]) {
        final fix = point(sample.$1, sample.$2);
        await recorder.record(fix, fix.time);
      }
      expect(recorder.active!.walkingDuration, const Duration(seconds: 15));
      final id = recorder.activeId;
      await recorder.stop(endedAt: start.add(const Duration(minutes: 5)));
      await recorder.sync();
      final restored = BreadcrumbRecorder(repository, preferences);
      await restored.openAccount('synthetic');
      expect(
        restored.trips.single.walkingDuration,
        const Duration(seconds: 15),
      );
      expect(
        restored.trips.single.endedAt!.difference(start),
        const Duration(minutes: 5),
      );
      repository.offline = false;
      await restored.sync();
      expect(
        repository.saved['synthetic/$id']!.walkingDuration,
        const Duration(seconds: 15),
      );
    },
  );
  test(
    'legacy elapsed duration remains available as elapsed but is never presented as measured walking',
    () {
      final old = BreadcrumbTrip.parse('old', {
        'ownerId': 'synthetic',
        'name': 'Old trip',
        'startedAt': 0,
        'endedAt': 120000,
        'durationSeconds': 120,
        'status': 'completed',
      });
      expect(old!.recordedDurationSeconds, 120);
      expect(old.walkingDuration, isNull);
    },
  );
}
