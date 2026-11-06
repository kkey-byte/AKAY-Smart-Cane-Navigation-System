import 'package:app_mobile/models/breadcrumb_trip.dart';
import 'package:app_mobile/pages/shared/breadcrumb_history_page.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/dashboard_widgets/report_details_view.dart';
import 'package:app_mobile/widgets/track/breadcrumb_trip_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Routes extends NavigatorObserver {
  Route<dynamic>? latest;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      latest = route;
}

void main() {
  for (final localOwner in [false, true]) {
    testWidgets(
      'Report track entry preserves ${localOwner ? "owner" : "caregiver"} detail permissions',
      (tester) async {
        final observer = _Routes();
        final trip = BreadcrumbTrip(
          id: 'test-track',
          ownerId: 'synthetic',
          name: 'Synthetic saved track',
          startedAt: DateTime(2026, 1, 1),
          points: const [],
          status: 'completed',
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: GabayTheme.lightTheme,
            navigatorObservers: [observer],
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
        final tile = find.byType(BreadcrumbTripTile);
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        final route = observer.latest! as MaterialPageRoute<void>;
        final page =
            route.builder(tester.element(find.byType(ReportDetailsView)))
                as BreadcrumbTripPage;
        expect(page.trip.id, 'test-track');
        expect(page.localOwner, localOwner);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }
}
