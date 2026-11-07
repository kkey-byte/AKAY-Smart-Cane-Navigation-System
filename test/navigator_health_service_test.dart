import 'dart:convert';
import 'package:app_mobile/services/navigator_health_service.dart';
import 'package:app_mobile/services/secure_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'fetches selected navigator using authorized endpoint and keeps explicit health clears',
    () async {
      final service = NavigatorHealthService(
        api: SecureApi(
          idToken: () async => 'synthetic-token',
          bases: ['https://example.test/api'],
          revision: () => 1,
          client: MockClient((request) async {
            expect(request.url.path, '/api/v2/navigators/navigator-a/health');
            expect(request.headers['Authorization'], 'Bearer synthetic-token');
            expect(request.method, 'GET');
            return http.Response(
              jsonEncode({
                'navigator': {'uid': 'navigator-a', 'phone': 'Synthetic phone'},
                'patientProfile': {
                  'medicalConditions': 'Old profile condition',
                  'bloodType': 'Synthetic type',
                },
                'health_status': {
                  'height': '170.5',
                  'medical_conditions': null,
                  'allergies': '',
                },
              }),
              200,
            );
          }),
        ),
      );
      final details = await service.watch('navigator-a').first;
      expect(details.uid, 'navigator-a');
      expect(details.profile.bloodType, 'Synthetic type');
      expect(details.health!.height, 170.5);
      expect(details.health!.medicalConditions, isNull);
      expect(details.health!.allergies, '');
    },
  );

  test(
    'wrong identity and revoked access fail instead of returning another record',
    () async {
      for (final response in [
        http.Response('{"navigator":{"uid":"caregiver"}}', 200),
        http.Response('{"message":"Access revoked"}', 403),
      ]) {
        final service = NavigatorHealthService(
          api: SecureApi(
            idToken: () async => 'synthetic-token',
            bases: ['https://example.test/api'],
            revision: () => 1,
            client: MockClient((_) async => response),
          ),
        );
        await expectLater(
          service.watch('navigator-a').first,
          throwsA(anyOf(isA<FormatException>(), isA<SecureApiException>())),
        );
      }
    },
  );
}
