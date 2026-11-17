import 'dart:convert';
import 'package:app_mobile/services/breadcrumb_repository.dart';
import 'package:app_mobile/services/dashboard_service.dart';
import 'package:app_mobile/services/secure_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  SecureApi api(Map<String, dynamic> response, {int status = 200}) => SecureApi(
    idToken: () async => 'synthetic-token',
    revision: () => 1,
    bases: ['https://example.test'],
    client: MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer synthetic-token');
      return http.Response(jsonEncode(response), status);
    }),
  );
  test(
    'selected navigator receives the matching remote marker and recorded path',
    () async {
      final service = DashboardService(
        api: api({
          'navigator': {'uid': 'nav', 'name': 'Synthetic navigator'},
          'location': {
            'latitude': 10,
            'longitude': 20,
            'time': 1000,
            'source': 'phone_gps',
            'deviceId': 'physical-cane',
            'assignmentId': 'assignment',
            'live': true,
          },
          'points': [
            {'latitude': 9.9, 'longitude': 20, 'time': 900},
            {'latitude': 10, 'longitude': 20, 'time': 1000},
          ],
          'recordedTrip': {'id': 'cane-trip'},
        }),
      );
      final seen = await service.watch('nav').first;
      expect(seen.uid, 'nav');
      expect(seen.position!.latitude, 10);
      expect(seen.points.first.latitude, 9.9);
      expect(seen.points.last.latitude, 10);
      expect(seen.assignmentId, 'assignment');
      expect(seen.recordedTripId, 'cane-trip');
    },
  );
  test(
    'cane coordinates never become the navigator phone marker or path',
    () async {
      for (final hasPhone in [false, true]) {
        final service = DashboardService(
          api: api({
            'navigator': {'uid': 'nav'},
            'location': {'source': 'cane_gps', 'latitude': 11, 'longitude': 21},
            if (hasPhone)
              'phoneLocation': {
                'source': 'phone_gps',
                'latitude': 10,
                'longitude': 20,
                'time': 1000,
                'live': false,
              },
            'points': [
              {'latitude': 11, 'longitude': 21},
            ],
            'recordedTrip': {'id': 'cane-trip'},
          }),
        );
        final seen = await service.watch('nav').first;
        expect(seen.position?.latitude, hasPhone ? 10 : null);
        expect(seen.points, isEmpty);
        expect(seen.recordedTripId, isNull);
        expect(seen.fresh(DateTime.now()), isFalse);
      }
    },
  );
  test(
    'mismatched navigator responses fail closed rather than becoming another patient marker',
    () async {
      final service = DashboardService(
        api: api({
          'navigator': {'uid': 'another-nav'},
          'location': {'latitude': 10, 'longitude': 20, 'time': 1000},
        }),
      );
      await expectLater(
        service.watch('nav').first,
        throwsA(
          isA<SecureApiException>().having((e) => e.status, 'status', 403),
        ),
      );
    },
  );
  test(
    'revoked consent is delivered as an error, not an empty successful monitoring response',
    () async {
      final service = DashboardService(
        api: api({
          'code': 'access_revoked',
          'message': 'Active consent required.',
        }, status: 403),
      );
      await expectLater(
        service.watch('nav').first,
        throwsA(
          isA<SecureApiException>().having(
            (e) => e.code,
            'code',
            'access_revoked',
          ),
        ),
      );
    },
  );
  test(
    'recorded-route response must belong to the selected navigator',
    () async {
      final repository = FirebaseBreadcrumbRepository(
        api: api({
          'trip': {
            'ownerId': 'another-nav',
            'name': 'Synthetic trip',
            'startedAt': 1000,
            'status': 'completed',
            'points': {},
          },
        }),
      );
      await expectLater(
        repository.watchTrip('nav', 'trip').first,
        throwsA(
          isA<SecureApiException>().having((e) => e.status, 'status', 403),
        ),
      );
    },
  );
}
