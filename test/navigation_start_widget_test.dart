import 'dart:async';
import 'package:app_mobile/models/linked_navigator.dart';
import 'package:app_mobile/models/route_plan.dart';
import 'package:app_mobile/pages/screens/route_planner_page.dart';
import 'package:app_mobile/services/destination_search_service.dart';
import 'package:app_mobile/services/map_place_service.dart';
import 'package:app_mobile/services/navigator_location_service.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const navigator = LinkedNavigator(
  id: 'test',
  name: 'Navigator',
  address: 'Origin',
  location: LatLng(1, 2),
  status: '',
  batteryPercent: -1,
);
const placeA = MapPlace(
  id: '',
  name: 'Destination A',
  address: 'Saved address A',
  latitude: 1.001,
  longitude: 2.001,
);
const placeB = MapPlace(
  id: 'akay_2',
  name: 'Destination B',
  address: 'Saved address B',
  latitude: 1.002,
  longitude: 2.002,
);
RoutePlanResult resultFor(MapPlace place) => RoutePlanResult(
  navigator: navigator,
  destination: place,
  estimatedTime: '1 min',
  estimatedDistance: '100 m',
  currentSpeed: '',
  navigationStatus: 'Navigating',
  polylinePoints: [navigator.location, place.latLng],
  tripStartedAt: DateTime.now(),
);

class History extends DestinationSearchService {
  bool failSave = false;
  @override
  Future<List<MapPlace>> loadRecentSentDestinations(String navigatorId) async =>
      [placeA, placeB];
  @override
  Future<void> saveRecentSentDestination({
    required String navigatorId,
    required MapPlace place,
  }) async {
    if (failSave) throw StateError('Synthetic preference failure');
  }
}

class Routes extends MapPlaceService {
  Routes(this.build);
  final Future<RoutePlanResult> Function(MapPlace) build;
  int calls = 0;
  LinkedNavigator? lastNavigator;
  @override
  Future<RoutePlanResult> buildRoutePlan({
    required LinkedNavigator navigator,
    required MapPlace destination,
  }) {
    calls++;
    lastNavigator = navigator;
    return build(destination);
  }
}

class DeniedLocation extends GeolocatorPlatform {
  bool denied = true;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      denied ? LocationPermission.deniedForever : LocationPermission.whileInUse;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 1,
    longitude: 2,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  Future<void> open(
    WidgetTester tester,
    Routes routes,
    History history,
    void Function(RoutePlanResult?) onResult, {
    bool live = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                onResult(
                  await Navigator.of(context).push<RoutePlanResult>(
                    MaterialPageRoute(
                      builder: (_) => RoutePlannerPage(
                        initialNavigatorId: 'test',
                        isNavigatorMode: live,
                        linkedNavigators: const [navigator],
                        placeService: routes,
                        destinationSearch: history,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open planner'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open planner'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'recent destination remains retryable after error; history failure cannot block valid route',
    (tester) async {
      var attempt = 0;
      RoutePlanResult? completed;
      final routes = Routes((place) async {
        if (++attempt == 1) {
          throw const NavigationRouteException(
            'Provider unavailable. Retry this destination.',
          );
        }
        return resultFor(place);
      });
      await open(
        tester,
        routes,
        History()..failSave = true,
        (value) => completed = value,
      );
      await tester.tap(find.text('Destination A', findRichText: true).last);
      await tester.pumpAndSettle();
      expect(
        find.text('Provider unavailable. Retry this destination.'),
        findsOneWidget,
      );
      expect(completed, isNull);
      await tester.tap(find.text('Destination A', findRichText: true).last);
      await tester.pumpAndSettle();
      expect(routes.calls, 2);
      expect(completed?.destination, same(placeA));
    },
  );
  testWidgets('destination change ignores an earlier route response', (
    tester,
  ) async {
    final first = Completer<RoutePlanResult>(),
        second = Completer<RoutePlanResult>();
    RoutePlanResult? completed;
    final routes = Routes(
      (place) => identical(place, placeA) ? first.future : second.future,
    );
    await open(tester, routes, History(), (value) => completed = value);
    await tester.tap(find.text('Destination A', findRichText: true).last);
    await tester.pump();
    await tester.tap(find.text('Destination B', findRichText: true).last);
    await tester.pump();
    first.complete(resultFor(placeA));
    await tester.pump();
    expect(completed, isNull);
    second.complete(resultFor(placeB));
    await tester.pumpAndSettle();
    expect(completed?.destination, same(placeB));
    expect(routes.calls, 2);
  });
  testWidgets('repeated taps while routing make one request', (tester) async {
    final pending = Completer<RoutePlanResult>();
    RoutePlanResult? completed;
    final routes = Routes((_) => pending.future);
    await open(tester, routes, History(), (value) => completed = value);
    await tester.tap(find.text('Destination A').last);
    await tester.pump();
    await tester.tap(find.text('Destination A').last);
    await tester.pump();
    expect(routes.calls, 1);
    pending.complete(resultFor(placeA));
    await tester.pumpAndSettle();
    expect(completed?.destination, same(placeA));
  });
  testWidgets(
    'permission recovery continues routing with the refreshed origin',
    (tester) async {
      final old = GeolocatorPlatform.instance;
      final gps = DeniedLocation();
      GeolocatorPlatform.instance = gps;
      NavigatorLocationService.instance.stopTracking(clearLocation: true);
      RoutePlanResult? completed;
      final routes = Routes((place) async => resultFor(place));
      try {
        await open(
          tester,
          routes,
          History(),
          (value) => completed = value,
          live: true,
        );
        gps.denied = false;
        await tester.tap(find.text('Destination A').last);
        await tester.pumpAndSettle();
        expect(routes.calls, 1);
        expect(routes.lastNavigator?.location, const LatLng(1, 2));
        expect(completed?.destination, same(placeA));
        await tester.pumpWidget(const SizedBox());
      } finally {
        NavigatorLocationService.instance.stopTracking(clearLocation: true);
        GeolocatorPlatform.instance = old;
      }
    },
  );
  testWidgets(
    'denied current location gives a clear message and repeated taps stay usable',
    (tester) async {
      final old = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = DeniedLocation();
      NavigatorLocationService.instance.stopTracking(clearLocation: true);
      final routes = Routes((place) async => resultFor(place));
      try {
        await open(tester, routes, History(), (_) {}, live: true);
        for (var attempt = 0; attempt < 2; attempt++) {
          await tester.tap(find.text('Destination A', findRichText: true).last);
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Location permission is required'),
            findsOneWidget,
          );
          expect(routes.calls, 0);
        }
        await tester.pumpWidget(const SizedBox());
      } finally {
        NavigatorLocationService.instance.stopTracking(clearLocation: true);
        GeolocatorPlatform.instance = old;
      }
    },
  );
}
