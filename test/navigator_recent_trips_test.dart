import 'package:app_mobile/models/breadcrumb_trip.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/dashboard_widgets/recorded_reports.dart';
import 'package:app_mobile/widgets/dashboard_widgets/report_details_view.dart';
import 'package:app_mobile/widgets/track/breadcrumb_trip_records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BreadcrumbTrip track(
  String id,
  int day, {
  String owner = 'navigator',
  String status = 'completed',
  List<BreadcrumbPoint> points = const [],
}) => BreadcrumbTrip(
  id: id,
  ownerId: owner,
  name: id,
  startedAt: DateTime(2026, 1, day),
  status: status,
  points: points,
);

void main() {
  test(
    'current and previous local tracks overlay uploads once, newest first',
    () {
      final current = track(
        'Current walk',
        3,
        status: 'recording',
        points: [BreadcrumbPoint(7.3, 125.6, DateTime(2026, 1, 3), 5)],
      );
      final result = mergeNavigatorReportTrips(
        ownerId: 'navigator',
        remote: [track('Uploaded walk', 1), track('Current walk', 3)],
        local: [track('Previous unsynced walk', 2), current],
      );
      expect(result!.map((trip) => trip.id), [
        'Current walk',
        'Previous unsynced walk',
        'Uploaded walk',
      ]);
      expect(result.first.isRecording, isTrue);
      expect(result.first.points, isNotEmpty);
    },
  );

  test(
    'offline cache is available while loading and another account stays hidden',
    () {
      final current = track('Current walk', 3, status: 'recording');
      expect(
        mergeNavigatorReportTrips(
          ownerId: 'navigator',
          remote: null,
          local: [
            current,
            track('Other account', 4, owner: 'other'),
          ],
        ),
        [current],
      );
      expect(
        mergeNavigatorReportTrips(
          ownerId: 'navigator',
          remote: null,
          local: [track('Other account', 4, owner: 'other')],
        ),
        isNull,
      );
      expect(
        mergeNavigatorReportTrips(ownerId: 'navigator', remote: [], local: []),
        isEmpty,
      );
    },
  );

  testWidgets('Recent Trips displays current and previous breadcrumb entries', (
    tester,
  ) async {
    final records = mergeNavigatorReportTrips(
      ownerId: 'navigator',
      remote: null,
      local: [
        track('Current walk', 3, status: 'recording'),
        track('Previous walk', 2),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecordedReportContent(
              trips: const [],
              recentTrips: records,
              localOwner: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Recent Trips'));
    expect(
      tester
          .widget<BreadcrumbTripRecords>(find.byType(BreadcrumbTripRecords))
          .trips,
      hasLength(2),
    );
    expect(find.byIcon(Icons.directions_walk_rounded), findsNWidgets(2));
    expect(find.text('Current walk'), findsOneWidget);
    expect(find.text('Previous walk'), findsOneWidget);
    expect(find.text('My tracks · Record without a destination'), findsNothing);
    expect(
      tester
          .widget<ReportDetailsView>(find.byType(ReportDetailsView))
          .values['Total Route'],
      '0 recorded trips',
    );
    final current = tester.getTopLeft(find.text('Current walk'));
    final previous = tester.getTopLeft(find.text('Previous walk'));
    if (current.dy == previous.dy) {
      expect(current.dx, lessThan(previous.dx));
    } else {
      expect(current.dy, lessThan(previous.dy));
    }
    expect(tester.takeException(), isNull);
  });
}
