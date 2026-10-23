import 'package:app_mobile/models/breadcrumb_trip.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/track/breadcrumb_trip_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 29, 12);
  final trip = BreadcrumbTrip(
    id: 'trip',
    ownerId: 'owner',
    name: 'Walking to the hospital via New Visayas',
    startedAt: now,
    points: [BreadcrumbPoint(7.3, 125.68, now, 10)],
  );

  testWidgets(
    'track tile is readable at large text size in both themes and opens the track',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final theme in [GabayTheme.lightTheme, GabayTheme.darkTheme]) {
        var opened = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: ListView(
                  children: [
                    BreadcrumbTripTile(
                      trip: trip,
                      now: now,
                      connected: true,
                      onTap: () => opened = true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Live · Recording'), findsOneWidget);
        await tester.tap(find.text(trip.name));
        expect(opened, isTrue);
      }
    },
  );

  test('offline, stale and finished tracks never claim to be live', () {
    expect(breadcrumbStatus(trip, now, connected: false), contains('Offline'));
    expect(
      breadcrumbStatus(trip, now.add(const Duration(minutes: 2))),
      'No recent GPS update',
    );
    expect(breadcrumbStatus(trip.copyWith(status: 'completed'), now), 'Saved');
  });
}
