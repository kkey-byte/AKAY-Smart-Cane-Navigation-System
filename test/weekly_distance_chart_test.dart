import 'package:app_mobile/models/breadcrumb_trip.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/dashboard_widgets/weekly_distance_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BreadcrumbTrip saved(String id, DateTime start, double meters) =>
    BreadcrumbTrip(
      id: id,
      ownerId: 'synthetic',
      name: 'Test track',
      startedAt: start,
      points: const [],
      status: 'completed',
      recordedDistanceMeters: meters,
      recordedPointCount: 5,
    );

void main() {
  test(
    'Saved summaries aggregate by local weekday, excluding other weeks and future captures',
    () {
      final now = DateTime(2026, 11, 13, 18);
      final monday = saved('one', DateTime(2026, 11, 9, 9), 250);
      final result = recordedDistancesThisWeek([
        monday,
        monday,
        saved('two', DateTime(2026, 11, 9, 17).toUtc(), 750),
        saved('three', DateTime(2026, 11, 10, 9), 500),
        saved('last-week', DateTime(2026, 11, 8, 22), 9999),
        saved('future', DateTime(2026, 11, 14, 9), 9999),
        saved('next-week', DateTime(2026, 11, 16, 9), 9999),
      ], now);
      expect(result, [1000, 500, 0, 0, 0, 0, 0]);
    },
  );
  test('Calendar week crosses a year boundary and includes Sunday', () {
    expect(
      recordedDistancesThisWeek([
        saved('mon', DateTime(2026, 12, 28, 8), 100),
        saved('sun', DateTime(2027, 1, 3, 8), 200),
        saved('old', DateTime(2026, 12, 27, 8), 999),
      ], DateTime(2027, 1, 3, 18)),
      [100, 0, 0, 0, 0, 0, 200],
    );
  });
  for (final large in [false, true]) {
    testWidgets(
      'Chart shows saved distances and reacts to new data large=$large',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final now = DateTime(2026, 11, 13, 18);
        Widget page(List<BreadcrumbTrip>? trips) => MaterialApp(
          theme: large ? GabayTheme.darkTheme : GabayTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: WeeklyDistanceChart(trips: trips, now: now),
              ),
            ),
          ),
        );
        await tester.pumpWidget(page(null));
        expect(find.text('Saved activity is unavailable.'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('weekly-distance-bar-0')),
          findsNothing,
        );
        await tester.pumpWidget(page([]));
        expect(find.text('No recorded distance this week.'), findsNothing);
        expect(find.text('Recorded distance per day'), findsNothing);
        expect(find.textContaining('Based on loaded'), findsNothing);
        expect(find.text('0 m this week'), findsNothing);
        await tester.pumpWidget(
          page([
            saved('mon', DateTime(2026, 11, 9), 1000),
            saved('tue', DateTime(2026, 11, 10), 500),
          ]),
        );
        expect(find.text('1.50 km this week'), findsNothing);
        final mon = tester
            .getSize(find.byKey(const ValueKey('weekly-distance-bar-0')))
            .height;
        final tue = tester
            .getSize(find.byKey(const ValueKey('weekly-distance-bar-1')))
            .height;
        expect(mon, tue * 2);
        await tester.pumpWidget(
          page([saved('mon', DateTime(2026, 11, 9), 2000)]),
        );
        expect(find.text('2.00 km this week'), findsNothing);
        expect(
          find.byKey(const ValueKey('weekly-distance-bar-1')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
