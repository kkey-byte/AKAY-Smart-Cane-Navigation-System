import 'dart:async';
import 'package:app_mobile/models/breadcrumb_trip.dart';
import 'package:app_mobile/pages/shared/breadcrumb_history_page.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/dashboard_widgets/report_details_view.dart';
import 'package:app_mobile/widgets/track/breadcrumb_trip_records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Routes extends NavigatorObserver {
  int pushes = 0;
  Route<dynamic>? latest;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    latest = route;
  }
}

void main() {
  final trip = BreadcrumbTrip(
    id: 'test-track',
    ownerId: 'synthetic',
    name: 'Synthetic saved track',
    startedAt: DateTime(2026, 1, 1),
    endedAt: DateTime(2026, 1, 1, 0, 2),
    points: const [],
    status: 'completed',
  );
  for (final localOwner in [false, true]) {
    testWidgets(
      'Report cards preserve ${localOwner ? "owner" : "caregiver"} detail permissions',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: GabayTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ReportDetailsView(
                  values: const {
                    'Trips Today': '0',
                    'This Week': '0',
                    'Total Distance': '0 km',
                    'Total Route': '1 recorded trip',
                  },
                  trips: [trip],
                  localOwner: localOwner,
                ),
              ),
            ),
          ),
        );
        final records = tester.widget<BreadcrumbTripRecords>(
          find.byType(BreadcrumbTripRecords),
        );
        expect(records.localOwner, localOwner);
        expect(
          find.text('My tracks · Record without a destination'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'View route opens a modal, closes its subscription and hides denied details (${localOwner ? "owner" : "caregiver"})',
      (tester) async {
        final observer = _Routes();
        final source = StreamController<BreadcrumbTrip?>.broadcast();
        await tester.pumpWidget(
          MaterialApp(
            theme: GabayTheme.lightTheme,
            navigatorObservers: [observer],
            home: Scaffold(
              body: SingleChildScrollView(
                child: BreadcrumbTripRecords(
                  trips: [trip],
                  localOwner: localOwner,
                  watchTrip: (owner, id) {
                    expect(owner, 'synthetic');
                    expect(id, 'test-track');
                    return source.stream;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('View route'));
        await tester.pumpAndSettle();
        expect(observer.pushes, 2);
        expect(observer.latest, isA<DialogRoute<void>>());
        expect(find.byType(Dialog), findsOneWidget);
        final detail = tester.widget<BreadcrumbTripPage>(
          find.byType(BreadcrumbTripPage),
        );
        expect(detail.embedded, isTrue);
        expect(detail.localOwner, localOwner);
        expect(source.hasListener, isTrue);
        source.add(trip);
        await tester.pump();
        expect(find.textContaining('Recorded distance:'), findsOneWidget);
        expect(find.text('Duration: 2 min 0 sec'), findsOneWidget);
        source.addError(StateError('Synthetic access denied'));
        await tester.pump();
        expect(find.textContaining('Recorded distance:'), findsNothing);
        expect(
          find.textContaining('Track access is unavailable'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.byTooltip('Close trip details'));
        await tester.tap(find.byTooltip('Close trip details'));
        await tester.pumpAndSettle();
        expect(find.byType(BreadcrumbTripPage), findsNothing);
        expect(find.byType(Dialog), findsNothing);
        expect(source.hasListener, isFalse);
        await source.close();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'record cards use icons and adapt from two columns to one at large text in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final other = BreadcrumbTrip(
        id: 'other',
        ownerId: 'synthetic',
        name: 'Second walk',
        startedAt: DateTime(2026, 1, 2),
        points: const [],
        status: 'completed',
      );
      for (final theme in [GabayTheme.lightTheme, GabayTheme.darkTheme]) {
        for (final scale in [1.0, 2.0]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: BreadcrumbTripRecords(
                        trips: [trip, other],
                        localOwner: false,
                        watchTrip: (_, _) => Stream.value(trip),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.directions_walk_rounded), findsNWidgets(2));
          final a = tester.getTopLeft(find.text(trip.name)),
              b = tester.getTopLeft(find.text(other.name));
          expect(a.dy, isNot(b.dy));
          expect(a.dx, b.dx);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('View route').first);
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsOneWidget);
          await tester.ensureVisible(find.text('0 GPS points · Phone GPS'));
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('Close trip details'));
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing);
        }
      }
    },
  );
}
