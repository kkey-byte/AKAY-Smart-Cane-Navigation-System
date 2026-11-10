import 'dart:convert';
import 'package:app_mobile/models/breadcrumb_trip.dart';
import 'package:app_mobile/services/breadcrumb_repository.dart';
import 'package:app_mobile/services/secure_api.dart';
import 'package:app_mobile/services/breadcrumb_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'HTTP success without explicit upload confirmation keeps the durable queue',
    () async {
      SharedPreferences.setMockInitialValues({});
      var acknowledged = false;
      final api = SecureApi(
        idToken: () async => 'synthetic-token',
        revision: () => 1,
        bases: ['https://example.test'],
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode({'accepted': acknowledged}), 200),
        ),
      );
      final recorder = BreadcrumbRecorder(
        FirebaseBreadcrumbRepository(api: api),
        await SharedPreferences.getInstance(),
      );
      await recorder.openAccount('owner');
      final now = DateTime(2026, 11, 1);
      await recorder.start('Trip', BreadcrumbPoint(10, 20, now, 5));
      await recorder.sync();
      expect(recorder.hasPending, isTrue);
      acknowledged = true;
      await recorder.sync();
      expect(recorder.hasPending, isFalse);
    },
  );
  test(
    'bounded stable uploads retry capture times and finalize last',
    () async {
      final requests = <http.Request>[];
      var fail = true;
      final api = SecureApi(
        idToken: () async => 'synthetic-token',
        revision: () => 1,
        bases: ['https://example.test'],
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            fail && request.url.path.endsWith('/summary')
                ? '{"message":"synthetic failure"}'
                : '{"accepted":true}',
            fail && request.url.path.endsWith('/summary') ? 503 : 200,
          );
        }),
      );
      final time = DateTime(2026, 1, 1);
      final trip = BreadcrumbTrip(
        id: 'trip',
        ownerId: 'owner',
        name: 'Trip',
        startedAt: time,
        status: 'completed',
        endedAt: time.add(const Duration(minutes: 2)),
        points: [
          for (var i = 0; i < 85; i++)
            BreadcrumbPoint(10, 20, time.add(Duration(seconds: i)), 5),
        ],
      );
      await expectLater(
        FirebaseBreadcrumbRepository(api: api).save(trip),
        throwsA(isA<SecureApiException>()),
      );
      expect(requests, hasLength(4));
      final first = requests.take(3).map((r) => r.body).toList();
      fail = false;
      await FirebaseBreadcrumbRepository(api: api).save(trip);
      expect(requests.skip(4).take(3).map((r) => r.body), first);
      expect(requests.last.url.path, endsWith('/summary'));
      expect(jsonDecode(requests.last.body)['pointCount'], 85);
      final points = requests
          .take(3)
          .expand((r) => jsonDecode(r.body)['points'] as List)
          .toList();
      expect(points.map((p) => p['sequence']), List.generate(85, (i) => i));
      expect(points.first['sampledAt'], time.millisecondsSinceEpoch);
      expect(points.every((p) => !p.containsKey('deviceId')), isTrue);
    },
  );

  test(
    'summary pages require no coordinates and retain physical cane identity',
    () async {
      final api = SecureApi(
        idToken: () async => 'synthetic-token',
        revision: () => 1,
        bases: ['https://example.test'],
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'trips': {
                'trip': {
                  'ownerId': 'owner',
                  'name': 'Cane track',
                  'startedAt': 1000,
                  'status': 'completed',
                  'sourceType': 'cane_gps',
                  'deviceId': 'physical-cane',
                  'assignmentId': 'assignment',
                  'pointCount': 12,
                  'distanceMeters': 125.0,
                },
              },
              'nextCursor': null,
            }),
            200,
          ),
        ),
      );
      final rows = await FirebaseBreadcrumbRepository(
        api: api,
      ).watchTrips('owner').first;
      expect(rows.single.points, isEmpty);
      expect(rows.single.pointCount, 12);
      expect(rows.single.distanceMeters, 125);
      expect(rows.single.sourceType, 'cane_gps');
      expect(rows.single.deviceId, 'physical-cane');
    },
  );
}
