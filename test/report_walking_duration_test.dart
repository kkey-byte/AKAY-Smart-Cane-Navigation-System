import 'package:app_mobile/models/breadcrumb_trip.dart';
import 'package:app_mobile/widgets/dashboard_widgets/recorded_reports.dart';
import 'package:app_mobile/widgets/dashboard_widgets/report_details_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BreadcrumbTrip trip({Object? seconds, int? end}) =>
    BreadcrumbTrip.parse('trip', {
      'ownerId': 'navigator',
      'name': 'Test walk',
      'startedAt': 1000,
      'endedAt': end,
      'status': 'completed',
      'durationSeconds': seconds,
    })!;

void main() {
  test(
    'saved duration survives parsing, caching and copying without points',
    () {
      final recorded = trip(seconds: 125);
      expect(recorded.walkingDuration, const Duration(seconds: 125));
      expect(recorded.copyWith().walkingDuration, recorded.walkingDuration);
      expect(
        BreadcrumbTrip.parse('trip', recorded.toJson())!.walkingDuration,
        recorded.walkingDuration,
      );
    },
  );

  test('older trips use recorded timestamps and reject invalid durations', () {
    expect(trip(end: 61000).walkingDuration, const Duration(minutes: 1));
    expect(
      trip(seconds: -1, end: 61000).walkingDuration,
      const Duration(minutes: 1),
    );
    expect(trip().walkingDuration, isNull);
    expect(trip(end: 0).walkingDuration, isNull);
    expect(trip(seconds: 0).walkingDuration, Duration.zero);
  });

  for (final owner in [false, true]) {
    testWidgets('reports sum only today walking duration localOwner=$owner', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecordedReportContent(
                localOwner: owner,
                clock: () => DateTime(2026, 11, 11, 12),
                trips: [
                  datedTrip(DateTime(2026, 11, 11, 9), 3600),
                  datedTrip(DateTime(2026, 11, 11, 11), 120),
                  datedTrip(DateTime(2026, 11, 10, 9), 7200),
                  datedTrip(DateTime(2026, 11, 12, 9), 7200),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Walking Duration'), findsOneWidget);
      expect(find.text('1 hr 2 min'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<ReportDetailsView>(find.byType(ReportDetailsView).first)
            .trips,
        hasLength(4),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('daily duration resets at midnight without deleting history', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 11, 23, 59, 59);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecordedReportContent(
              clock: () => now,
              trips: [datedTrip(DateTime(2026, 11, 11, 9), 300)],
            ),
          ),
        ),
      ),
    );
    expect(find.text('5 min'), findsOneWidget);
    now = DateTime(2026, 11, 12);
    await tester.pump(const Duration(seconds: 1));
    final report = tester.widget<ReportDetailsView>(
      find.byType(ReportDetailsView).first,
    );
    expect(report.values['Walking Duration'], '0 sec');
    expect(report.trips, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });
}

BreadcrumbTrip datedTrip(DateTime start, int seconds) => BreadcrumbTrip(
  id: start.toIso8601String(),
  ownerId: 'navigator',
  name: 'Synthetic walk',
  startedAt: start,
  endedAt: start.add(Duration(seconds: seconds)),
  status: 'completed',
  points: const [],
  recordedDurationSeconds: seconds,
);
