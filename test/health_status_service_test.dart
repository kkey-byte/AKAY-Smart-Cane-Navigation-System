import 'dart:async';
import 'dart:convert';
import 'package:app_mobile/models/patient_health_status.dart';
import 'package:app_mobile/models/user_role.dart';
import 'package:app_mobile/services/app_session_service.dart';
import 'package:app_mobile/services/health_status_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final session = AppSessionService.instance;
  Future<void> login(String id) => session.loginSession(
    userEmail: '$id@example.test',
    userRole: UserRole.navigator,
    id: id,
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await login('synthetic-owner');
  });
  const value = PatientHealthStatus(
    height: 165,
    weight: 62.25,
    medicalConditions: 'Synthetic condition',
    allergies: 'Synthetic allergy',
    emergencyContactPhone: '09000000000',
  );

  test(
    'save sends only exact health columns and fetch round-trips numeric values',
    () async {
      Map<String, dynamic>? stored;
      final service = HealthStatusService(
        baseUrl: 'https://example.test/api',
        idToken: () async => 'synthetic-token',
        client: MockClient((request) async {
          expect(request.url.path, '/api/health-status');
          expect(request.headers['Authorization'], 'Bearer synthetic-token');
          if (request.method == 'PUT') {
            stored = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
            expect(stored!.keys.toSet(), {
              'height',
              'weight',
              'medical_conditions',
              'allergies',
              'emergency_contact_phone',
            });
          }
          return http.Response(jsonEncode({'health_status': stored}), 200);
        }),
      );
      expect(await service.fetch(), isNull);
      expect((await service.save(value)).toJson(), value.toJson());
      expect((await service.fetch())!.toJson(), value.toJson());
      expect(
        PatientHealthStatus.fromJson({
          'height': '165.00',
          'weight': '62.25',
        }).height,
        165,
      );
    },
  );

  test(
    'failed and unconfirmed saves are never reported as persisted',
    () async {
      for (final response in [
        http.Response('{}', 503),
        http.Response('{"health_status":null}', 200),
        http.Response('{"health_status":{"height":170}}', 200),
      ]) {
        final service = HealthStatusService(
          baseUrl: 'https://example.test/api',
          idToken: () async => 'synthetic',
          client: MockClient((_) async => response),
        );
        await expectLater(service.save(value), throwsException);
      }
    },
  );

  test('identity change while obtaining token prevents any write', () async {
    final token = Completer<String?>();
    var sent = false;
    final service = HealthStatusService(
      baseUrl: 'https://example.test/api',
      idToken: () => token.future,
      client: MockClient((_) async {
        sent = true;
        return http.Response('{}', 200);
      }),
    );
    final pending = service.save(value);
    final rejected = expectLater(pending, throwsException);
    await login('different-owner');
    token.complete('synthetic-token');
    await rejected;
    expect(sent, isFalse);
  });

  test('late response from a previous account is rejected', () async {
    final response = Completer<http.Response>();
    final service = HealthStatusService(
      baseUrl: 'https://example.test/api',
      idToken: () async => 'synthetic',
      client: MockClient((_) => response.future),
    );
    final pending = service.fetch();
    final rejected = expectLater(pending, throwsException);
    await Future<void>.delayed(Duration.zero);
    await login('different-owner');
    response.complete(
      http.Response(jsonEncode({'health_status': value.toJson()}), 200),
    );
    await rejected;
  });
}
