import 'package:app_mobile/models/linked_navigator.dart';
import 'package:app_mobile/models/route_plan.dart';
import 'package:app_mobile/models/route_timeline_entry.dart';
import 'package:app_mobile/services/route_timeline_tracker.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/track/eta_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const destination = MapPlace(
  id: 'test',
  name: 'Hospital',
  address: 'New Visayas',
  latitude: 7.31,
  longitude: 125.68,
);

void main() {
  test(
    'timeline suppresses jitter and repeated addresses but records movement',
    () {
      final tracker = RouteTimelineTracker.instance;
      tracker.startTracking(destination);
      tracker.onLocationUpdate(
        geocodedAddress: 'First street',
        distanceMovedMeters: 40,
        location: const LatLng(7.30, 125.67),
      );
      final count = tracker.entries.length;
      tracker.onLocationUpdate(
        geocodedAddress: '7.30001, 125.67001',
        distanceMovedMeters: 2,
        location: const LatLng(7.30001, 125.67001),
      );
      expect(tracker.entries.length, count);
      tracker.onLocationUpdate(
        geocodedAddress: ' FIRST   STREET ',
        distanceMovedMeters: 100,
        location: const LatLng(7.301, 125.67),
      );
      expect(tracker.entries.length, count);
      tracker.onLocationUpdate(
        geocodedAddress: 'Second street',
        distanceMovedMeters: 5,
        location: const LatLng(7.301, 125.67),
      );
      expect(tracker.entries.length, count + 1);
      tracker.startTracking(destination);
      expect(tracker.entries.length, 1);
      tracker.reset();
    },
  );

  testWidgets('details and timeline switch and dismiss without layout errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    final route = RoutePlanResult(
      navigator: LinkedNavigatorService.selfNavigator,
      destination: destination,
      estimatedTime: '20 min',
      estimatedDistance: '1.5 km',
      currentSpeed: '4 km/h',
      navigationStatus: 'Navigating',
      polylinePoints: const [],
      tripStartedAt: DateTime(2026, 9, 29),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, show, _) => show
                  ? EtaCard(
                      route: route,
                      timelineEntries: List.generate(
                        12,
                        (i) => RouteTimelineEntry(
                          address: 'Street $i, New Visayas',
                          timestamp: DateTime(2026, 9, 29),
                        ),
                      ),
                      currentLocationAddress:
                          'New Visayas, Panabo City, Davao del Norte, Philippines',
                      onDragDismiss: () => visible.value = false,
                      onCancelDestination: () => visible.value = false,
                    )
                  : const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Route Timeline'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Navigation Details'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.drag(find.text('Navigation Details'), const Offset(0, 150));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(EtaCard), findsNothing);
  });
}
