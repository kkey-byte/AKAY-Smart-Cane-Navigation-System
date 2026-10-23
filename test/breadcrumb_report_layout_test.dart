import 'package:app_mobile/pages/caregiver/caregiver_reports.dart';
import 'package:app_mobile/pages/visually_impaired/visually_impaired_reports.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/track/breadcrumb_feature_card.dart';
import 'package:app_mobile/widgets/track/navigator_monitor_sheet.dart';
import 'package:app_mobile/models/linked_navigator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'caregiver patient selector handles shared patient status and unknown battery',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const navigator = LinkedNavigator(
        id: 'shared-patient',
        name: 'Shared Patient',
        address: '7.30000, 125.68000',
        location: LatLng(7.3, 125.68),
        status: 'Recording track',
        batteryPercent: -1,
      );
      var selected = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: Scaffold(
            body: NavigatorMonitorSheet(
              navigators: const [navigator],
              selectedId: navigator.id,
              showAllOnMap: true,
              onNavigatorSelected: (_) => selected = true,
              onShowAllChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Shared Patient'), findsOneWidget);
      expect(find.text('-1%'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Shared Patient'));
      expect(selected, isTrue);
    },
  );
  testWidgets(
    'both report pages retain report sections alongside breadcrumb entry',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final theme in [GabayTheme.lightTheme, GabayTheme.darkTheme]) {
        for (final page in [
          const ReportsPage(),
          const VisuallyImpairedReportsPage(),
        ]) {
          await tester.pumpWidget(MaterialApp(theme: theme, home: page));
          await tester.pumpAndSettle();
          expect(find.text('Reports'), findsOneWidget);
          expect(find.text('Trips Today'), findsOneWidget);
          expect(find.text('Walking Duration'), findsOneWidget);
          expect(find.text('Most Visited Places'), findsOneWidget);
          expect(find.text('Recent Trips'), findsOneWidget);
          expect(find.byType(BreadcrumbFeatureCard), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'additive breadcrumb card supports large text on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: BreadcrumbFeatureCard(caregiver: true, compact: true),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Breadcrumb tracks'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
