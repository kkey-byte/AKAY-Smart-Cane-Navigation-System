import 'package:app_mobile/models/breadcrumb_trip.dart';
import 'package:app_mobile/widgets/dashboard_widgets/recorded_reports.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/dashboard_widgets/location_card.dart';
import 'package:app_mobile/widgets/visually_impaired/vi_status_overview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reports distinguish absent data from recorded trips', (
    tester,
  ) async {
    final now = DateTime.now();
    Widget page(List<BreadcrumbTrip>? trips) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: RecordedReportContent(trips: trips)),
      ),
    );
    await tester.pumpWidget(page(null));
    expect(find.text('Unavailable'), findsNWidgets(4));
    await tester.pumpWidget(page([]));
    expect(find.text('No recorded trips yet.'), findsOneWidget);
    expect(find.text('0 recorded trips'), findsOneWidget);
    await tester.pumpWidget(
      page([
        BreadcrumbTrip(
          id: 'synthetic-trip',
          ownerId: 'synthetic-owner',
          name: 'Synthetic destination',
          startedAt: now,
          points: [],
          status: 'completed',
        ),
      ]),
    );
    expect(find.text('1 recorded trips'), findsOneWidget);
    expect(find.text('Synthetic destination'), findsOneWidget);
    expect(
      find.text('Unavailable'),
      findsOneWidget,
    ); // No GPS distance inferred.
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing telemetry has no fabricated reading or map image', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: const Scaffold(
          body: Column(children: [ViStatusOverviewCard(), LocationCard()]),
        ),
      ),
    );
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('Status unavailable'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.text('78%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
