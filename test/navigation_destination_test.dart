import 'dart:convert';
import 'package:app_mobile/models/linked_navigator.dart';
import 'package:app_mobile/models/route_plan.dart';
import 'package:app_mobile/models/search_destination.dart';
import 'package:app_mobile/services/map_place_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const origin = LinkedNavigator(
  id: 'test',
  name: 'Navigator',
  address: '',
  location: LatLng(1, 2),
  status: '',
  batteryPercent: -1,
);
Map<String, dynamic> routeBody(LatLng end) => {
  'code': 'Ok',
  'routes': [
    {
      'distance': 123,
      'duration': 100,
      'geometry': {
        'coordinates': [
          [2, 1],
          [2.001, 1.001],
          [end.longitude, end.latitude],
        ],
      },
      'legs': [],
    },
  ],
};
void main() {
  for (final source in [
    'nearby',
    'other searchable place',
    'database',
    'pin',
  ]) {
    test('$source routes with coordinates and no provider place ID', () async {
      final place = source == 'pin'
          ? const MapPlace(
              id: '',
              name: 'Pinned destination',
              address: '',
              latitude: 1.002,
              longitude: 2.002,
            )
          : SearchDestination.fromJson({
              'id': source == 'database' ? 'akay_42' : '',
              'name': source,
              'latitude': source == 'database'
                  ? '1.002'
                  : source == 'other searchable place'
                  ? 1.2
                  : 1.002,
              'longitude': source == 'database'
                  ? '2.002'
                  : source == 'other searchable place'
                  ? 2.2
                  : 2.002,
              'source': source,
            }).toMapPlace();
      final service = MapPlaceService(
        apiBaseUrl: 'http://10.0.2.2:5000/api',
        client: MockClient((request) async {
          expect(request.url.path, '/api/routing/walk');
          expect(
            request.url.queryParameters['coordinates'],
            '2.0,1.0;${place.longitude},${place.latitude}',
          );
          return http.Response(jsonEncode(routeBody(place.latLng)), 200);
        }),
      );
      final route = await service.buildRoutePlan(
        navigator: origin,
        destination: place,
      );
      expect(route.destination, same(place));
      expect(route.polylinePoints.first, origin.location);
      expect(route.polylinePoints.last, place.latLng);
      expect(route.estimatedDistance, '123 m');
    });
  }
  test(
    'map-pin reverse-geocoding fallback still supplies a routable destination',
    () async {
      final service = MapPlaceService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(routeBody(const LatLng(1.002, 2.002))),
            200,
          ),
        ),
      );
      final pin = await service.placeFromCoordinates(
        const LatLng(1.002, 2.002),
      );
      expect(pin.latitude, 1.002);
      expect(pin.longitude, 2.002);
      expect(
        (await service.buildRoutePlan(
          navigator: origin,
          destination: pin,
        )).polylinePoints.last,
        pin.latLng,
      );
    },
  );
  test(
    'invalid and missing coordinates never become zero or a clamped destination',
    () async {
      for (final coords in [
        {},
        {'latitude': 'bad', 'longitude': 2},
        {'latitude': 91, 'longitude': 2},
        {'latitude': 1, 'longitude': double.infinity},
      ]) {
        expect(
          () => SearchDestination.fromJson(Map<String, dynamic>.from(coords)),
          throwsFormatException,
        );
      }
      var calls = 0;
      final service = MapPlaceService(
        client: MockClient((_) async {
          calls++;
          throw StateError('Unexpected network');
        }),
      );
      for (final latitude in [double.nan, 91.0]) {
        await expectLater(
          service.buildRoutePlan(
            navigator: origin,
            destination: MapPlace(
              id: '',
              name: 'Invalid',
              address: '',
              latitude: latitude,
              longitude: 2,
            ),
          ),
          throwsA(isA<NavigationRouteException>()),
        );
      }
      expect(calls, 0);
    },
  );
  for (final status in [422, 429, 503]) {
    test(
      'HTTP $status reports an actionable error and a later attempt succeeds',
      () async {
        var calls = 0;
        final service = MapPlaceService(
          client: MockClient((_) async {
            calls++;
            return calls == 1
                ? http.Response('{}', status)
                : http.Response(
                    jsonEncode(routeBody(const LatLng(1.002, 2.002))),
                    200,
                  );
          }),
        );
        const place = MapPlace(
          id: '',
          name: 'Pin',
          address: '',
          latitude: 1.002,
          longitude: 2.002,
        );
        await expectLater(
          service.buildRoutePlan(navigator: origin, destination: place),
          throwsA(
            isA<NavigationRouteException>().having(
              (e) => e.message,
              'message',
              contains(
                status == 422
                    ? 'No walking route'
                    : status == 429
                    ? 'busy'
                    : 'unavailable',
              ),
            ),
          ),
        );
        expect(
          (await service.buildRoutePlan(
            navigator: origin,
            destination: place,
          )).destination,
          same(place),
        );
        expect(calls, 2);
      },
    );
  }
  test('network failure retains no permanent service lock', () async {
    var calls = 0;
    final service = MapPlaceService(
      client: MockClient((_) async {
        if (++calls == 1) {
          throw http.ClientException('Synthetic connection failure');
        }
        return http.Response(
          jsonEncode(routeBody(const LatLng(1.002, 2.002))),
          200,
        );
      }),
    );
    await expectLater(
      service.fetchWalkingRoute(origin.location, const LatLng(1.002, 2.002)),
      throwsA(
        isA<NavigationRouteException>().having(
          (e) => e.message,
          'message',
          contains('Cannot reach'),
        ),
      ),
    );
    expect(
      await service.fetchWalkingRoute(
        origin.location,
        const LatLng(1.002, 2.002),
      ),
      isNotNull,
    );
  });
}
