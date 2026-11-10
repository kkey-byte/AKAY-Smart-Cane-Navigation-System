import 'package:app_mobile/models/breadcrumb_trip.dart';
import 'package:app_mobile/services/breadcrumb_motion_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'breadcrumb_recorder_test.dart' show MemoryRepository;
import 'package:app_mobile/services/breadcrumb_recorder.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final start = DateTime(2026, 11, 7, 12);
  BreadcrumbPoint point(double meters, int seconds, {double accuracy = 8}) =>
      BreadcrumbPoint(
        meters / 111195,
        0,
        start.add(Duration(seconds: seconds)),
        accuracy,
      );
  List<BreadcrumbPoint> add(
    BreadcrumbMotionFilter filter,
    double meters,
    int seconds, {
    double accuracy = 8,
  }) => filter.add(
    point(meters, seconds, accuracy: accuracy),
    start.add(Duration(seconds: seconds)),
  );

  test(
    'stationary cluster never becomes a route, including heartbeat times',
    () {
      final filter = BreadcrumbMotionFilter()..reset(point(0, 0));
      for (var i = 1; i <= 120; i++) {
        expect(add(filter, i.isEven ? 7 : -7, i * 5), isEmpty);
      }
    },
  );

  test('wide stationary cluster stays within reported error margins', () {
    final filter = BreadcrumbMotionFilter()..reset(point(0, 0, accuracy: 50));
    for (var i = 1; i <= 20; i++) {
      expect(add(filter, i.isEven ? 45 : -45, i * 30, accuracy: 50), isEmpty);
    }
  });

  test('one excursion and opposite-side jitter cannot confirm movement', () {
    final filter = BreadcrumbMotionFilter()..reset(point(0, 0));
    expect(add(filter, 22, 10), isEmpty);
    expect(add(filter, -22, 15), isEmpty);
    expect(add(filter, 0, 20), isEmpty);
  });

  test(
    'slow walking accumulates displacement and retains confirmed departure',
    () {
      final filter = BreadcrumbMotionFilter()..reset(point(0, 0));
      expect(add(filter, 6, 15), isEmpty);
      expect(add(filter, 12, 30), isEmpty);
      expect(add(filter, 18, 45), isEmpty);
      expect(add(filter, 20, 50).map((p) => p.time), [
        start.add(const Duration(seconds: 45)),
        start.add(const Duration(seconds: 50)),
      ]);
      expect(add(filter, 38, 70), hasLength(1));
      expect(add(filter, 40, 110), isEmpty);
      expect(add(filter, 37, 140), isEmpty);
    },
  );

  test(
    'fast notifications still confirm, spikes and bad fixes are rejected',
    () {
      final filter = BreadcrumbMotionFilter()..reset(point(0, 0));
      expect(add(filter, 20, 10), isEmpty);
      expect(add(filter, 22, 12), isEmpty);
      expect(add(filter, 24, 14), isEmpty);
      expect(add(filter, 26, 16), hasLength(2));
      expect(add(filter, 1000, 18), isEmpty);
      expect(add(filter, 28, 20, accuracy: 90), isEmpty);
      expect(add(filter, 46, 25), hasLength(1));
    },
  );

  test(
    'stationary aggregation stays fresh and syncs without adding vertices',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = MemoryRepository();
      final recorder = BreadcrumbRecorder(
        repository,
        await SharedPreferences.getInstance(),
      );
      await recorder.openAccount('synthetic');
      await recorder.start('Synthetic track', point(0, 0));
      await recorder.sync();
      for (var i = 1; i <= 10; i++) {
        final fix = point(i.isEven ? 6 : -6, i * 30);
        await recorder.record(fix, fix.time);
      }
      expect(recorder.active!.points, hasLength(1));
      expect(recorder.active!.points.single.latitude, 0);
      expect(
        recorder.active!.isFresh(start.add(const Duration(seconds: 301))),
        isTrue,
      );
      await recorder.sync();
      expect(repository.saved.values.single.points.single.time, start);
      expect(
        repository.saved.values.single.lastSampledAt,
        start.add(const Duration(seconds: 300)),
      );
      await recorder.record(
        point(20, 310),
        start.add(const Duration(seconds: 310)),
      );
      await recorder.record(
        point(26, 315),
        start.add(const Duration(seconds: 315)),
      );
      final times = recorder.active!.points.map((p) => p.time).toList();
      expect(times, orderedEquals([...times]..sort()));
      expect(recorder.active!.points, hasLength(3));
    },
  );
}
