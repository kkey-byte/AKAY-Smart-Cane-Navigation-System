import 'dart:convert';
import 'package:app_mobile/services/pairing_service.dart';
import 'package:app_mobile/services/secure_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'requests a server challenge then submits only the entered code and challenge ID',
    () async {
      final paths = <String>[];
      final service = PairingService(
        api: SecureApi(
          idToken: () async => 'synthetic-token',
          bases: ['http://synthetic.invalid/api'],
          client: MockClient((request) async {
            paths.add(request.url.path);
            expect(request.method, 'POST');
            expect(request.headers['Authorization'], 'Bearer synthetic-token');
            if (paths.length == 1) {
              expect(jsonDecode(request.body), isEmpty);
              return http.Response(
                jsonEncode({
                  'registrationId': 'registration-id',
                  'code': 'ABCD23',
                  'expires_at': '2026-11-16T10:05:00Z',
                }),
                200,
              );
            }
            expect(jsonDecode(request.body), {
              'registrationId': 'registration-id',
              'code': 'ABCD23',
            });
            return http.Response('{"accepted":true}', 200);
          }),
        ),
      );
      final challenge = await service.requestCaneRegistration();
      expect(challenge.code, 'ABCD23');
      await service.confirmCaneRegistration(challenge.id, ' abcd23 ');
      expect(paths, [
        '/api/v2/devices/registration-code',
        '/api/v2/devices/registration-code/confirm',
      ]);
    },
  );

  test(
    'malformed server code and unconfirmed registration are not success',
    () async {
      final service = PairingService(
        api: SecureApi(
          idToken: () async => 'synthetic-token',
          bases: ['http://synthetic.invalid/api'],
          client: MockClient(
            (request) async => http.Response(
              request.url.path.endsWith('/confirm')
                  ? '{"accepted":false}'
                  : '{"code":"INVALID"}',
              200,
            ),
          ),
        ),
      );
      await expectLater(
        service.requestCaneRegistration('id', 'proof'),
        throwsFormatException,
      );
      await expectLater(
        service.confirmCaneRegistration('challenge', 'ABCD23'),
        throwsA(isA<SecureApiException>()),
      );
    },
  );
}
