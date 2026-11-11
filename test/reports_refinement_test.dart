import 'package:app_mobile/models/breadcrumb_trip.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/dashboard_widgets/report_details_view.dart';
import 'package:app_mobile/widgets/shared/gabay_metric_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const values = {
  'Trips Today': '123456789',
  'This Week': '987654321',
  'Total Distance': '123456.78 km recorded',
  'Total Route': '5',
};
void main() {
  for (final config in [(320.0, 1.0), (390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'Report tiles remain equal at width=${config.$1} scale=${config.$2}',
      (tester) async {
        tester.view.physicalSize = Size(config.$1, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: GabayTheme.darkTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(config.$2)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: ReportDetailsView(values: values, trips: []),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final wrap = tester.widget<Wrap>(
          find.descendant(
            of: find.byType(GabayMetricGrid),
            matching: find.byType(Wrap),
          ),
        );
        final tiles = wrap.children.cast<SizedBox>();
        expect(tiles, hasLength(4));
        expect(tiles.map((tile) => tile.height).toSet(), hasLength(1));
        expect(tiles.map((tile) => tile.width).toSet(), hasLength(1));
        final tileFinders = find.descendant(
          of: find.byType(GabayMetricGrid),
          matching: find.byType(SizedBox),
        );
        final tileElements = tileFinders
            .evaluate()
            .where(
              (element) =>
                  element.widget is SizedBox &&
                  (element.widget as SizedBox).height == tiles.first.height,
            )
            .toList();
        final first = tester.getTopLeft(find.byWidget(tileElements[0].widget));
        final second = tester.getTopLeft(find.byWidget(tileElements[1].widget));
        expect(first.dy, second.dy);
        expect(first.dx, lessThan(second.dx));
        expect(find.text('Navigation Events'), findsNothing);
        expect(find.text('Most Visited Places'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final owner in [false, true]) {
    testWidgets(
      'Recent trips shows two previews and all records in a centered modal owner=$owner',
      (tester) async {
        final trips = List.generate(
          5,
          (i) => BreadcrumbTrip(
            id: '$i',
            ownerId: 'synthetic',
            name: 'Test trip $i',
            startedAt: DateTime(2026, 1, i + 1),
            points: const [],
            status: 'completed',
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: GabayTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ReportDetailsView(
                  values: values,
                  trips: trips,
                  localOwner: owner,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Test trip 4'), findsOneWidget);
        expect(find.text('Test trip 3'), findsOneWidget);
        expect(find.text('Test trip 2'), findsNothing);
        expect(
          tester.getTopLeft(find.text('View All')).dy,
          lessThan(tester.getTopLeft(find.text('Test trip 4')).dy),
        );
        expect(
          tester.getTopLeft(find.text('View All')).dx,
          greaterThan(tester.getTopLeft(find.text('Recent Trips')).dx),
        );
        await tester.ensureVisible(find.text('View All'));
        await tester.tap(find.text('View All'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        final inDialog = find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Test trip 0'),
        );
        await tester.scrollUntilVisible(
          inDialog,
          180,
          scrollable: find
              .descendant(
                of: find.byType(Dialog),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(inDialog, findsOneWidget);
        await tester.tap(find.byTooltip('Close recent trips'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(find.text('Test trip 0'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
