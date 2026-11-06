import 'dart:async';
import 'dart:convert';
import 'package:app_mobile/services/map_place_service.dart';
import 'package:app_mobile/widgets/track/readable_place_text.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response namedPlace() => http.Response(
  jsonEncode({
    'display_name': 'Sample Street, Sample City',
    'name': 'Sample Street',
  }),
  200,
);
void main() {
  test(
    'browser uses an available HTTPS default without forbidden User-Agent header',
    () async {
      late Uri uri;
      final service = MapPlaceService(
        client: MockClient((request) async {
          uri = request.url;
          expect(
            request.headers.keys.any(
              (key) => key.toLowerCase() == 'user-agent',
            ),
            isFalse,
          );
          return namedPlace();
        }),
      );
      final place = await service.placeFromCoordinates(const LatLng(10, 20));
      expect(uri.host, 'nominatim.openstreetmap.org');
      expect(uri.path, '/reverse');
      expect(place.address, 'Sample Street, Sample City');
    },
    skip: !kIsWeb,
  );

  test(
    'duplicate nearby lookups share one request without changing map coordinates',
    () async {
      var calls = 0;
      final response = Completer<http.Response>();
      final service = MapPlaceService(
        reverseGeocodeBase: 'https://geocoder.example.test',
        reverseRequestInterval: Duration.zero,
        client: MockClient((request) {
          calls++;
          expect(request.url.queryParameters['lat'], '10.00001');
          return response.future;
        }),
      );
      final one = service.placeFromCoordinates(
        const LatLng(10.00001, 20.00001),
      );
      final two = service.placeFromCoordinates(
        const LatLng(10.00002, 20.00002),
      );
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      response.complete(namedPlace());
      final places = await Future.wait([one, two]);
      expect(places[0].address, 'Sample Street, Sample City');
      expect(places[1].latitude, 10.00002);
      expect(places[1].longitude, 20.00002);
      await service.placeFromCoordinates(const LatLng(10.00003, 20.00003));
      expect(calls, 1);
    },
  );

  test(
    'failed lookup can be retried and preserves routable coordinates',
    () async {
      var calls = 0;
      final service = MapPlaceService(
        reverseGeocodeBase: 'https://geocoder.example.test/',
        reverseRequestInterval: Duration.zero,
        client: MockClient(
          (request) async =>
              ++calls == 1 ? http.Response('Unavailable', 503) : namedPlace(),
        ),
      );
      final fallback = await service.placeFromCoordinates(const LatLng(10, 20));
      expect(fallback.latitude, 10);
      expect(fallback.longitude, 20);
      await service.placeFromCoordinates(const LatLng(10, 20));
      expect(calls, 1);
      final retried = await service.placeFromCoordinates(
        const LatLng(10, 20),
        forceRefresh: true,
      );
      expect(calls, 2);
      expect(retried.address, 'Sample Street, Sample City');
    },
  );

  testWidgets(
    'current-location label loads a name and hides numerical coordinates',
    (tester) async {
      final name = Completer<String?>();
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: Scaffold(
            body: ReadablePlaceText(
              '10, 20',
              showCoordinateFallback: false,
              lookup: (_) => name.future,
            ),
          ),
        ),
      );
      expect(find.text('Finding location name…'), findsOneWidget);
      expect(find.text('10, 20'), findsNothing);
      name.complete('Sample Street, Sample City');
      await tester.pumpAndSettle();
      expect(find.text('Sample Street, Sample City'), findsOneWidget);
    },
  );

  testWidgets(
    'lookup failure offers retry instead of caching failure forever',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: Scaffold(
            body: ReadablePlaceText(
              '10, 20',
              showCoordinateFallback: false,
              lookup: (_) async => ++calls == 1 ? null : 'Recovered street',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Location name unavailable'), findsOneWidget);
      await tester.tap(find.byTooltip('Retry location name'));
      await tester.pumpAndSettle();
      expect(find.text('Recovered street'), findsOneWidget);
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
