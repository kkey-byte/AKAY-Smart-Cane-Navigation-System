import 'dart:convert';
import 'package:app_mobile/services/auth_service.dart';
import 'package:app_mobile/services/secure_api.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class PasswordUser extends Fake implements User {
  bool reject = false;
  final events = <String>[];
  @override
  String get uid => 'synthetic-owner';
  @override
  String get email => 'synthetic@example.test';
  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    events.add('verify');
    if (reject) throw FirebaseAuthException(code: 'wrong-password');
    return PasswordCredential();
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    expect(forceRefresh, isTrue);
    events.add('token');
    return 'synthetic-token';
  }
}

class PasswordCredential extends Fake implements UserCredential {}

class PasswordAuth extends Fake implements FirebaseAuth {
  final person = PasswordUser();
  @override
  User get currentUser => person;
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    expect(email, person.email);
    expect(password, 'Synthetic!1');
    person.events.add('session');
    return PasswordCredential();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => SecureApi.preferredBase = null);
  test(
    'HTML endpoint failures retain status and never report password success',
    () async {
      for (final status in [404, 502, 200]) {
        final auth = PasswordAuth();
        var requests = 0;
        final service = AuthService(
          firebaseAuth: auth,
          baseUrl: 'https://synthetic.test/api',
          client: MockClient((_) async {
            requests++;
            return http.Response(
              '<html>Cannot POST /api/auth/change-password</html>',
              status,
              headers: {'content-type': 'text/html'},
            );
          }),
        );
        await expectLater(
          service.changePassword(
            currentPassword: 'Existing!1',
            newPassword: 'Synthetic!1',
          ),
          throwsA(
            isA<AuthException>()
                .having((e) => e.statusCode, 'HTTP status', status)
                .having(
                  (e) => e.code,
                  'error code',
                  status == 404
                      ? 'endpoint_unavailable'
                      : 'invalid_service_response',
                ),
          ),
        );
        expect(auth.person.events, ['verify', 'token']);
        expect(requests, 1);
      }
    },
  );
  test(
    'reauthenticates before updating and renews the session only on success',
    () async {
      final auth = PasswordAuth();
      var status = 200;
      final service = AuthService(
        firebaseAuth: auth,
        baseUrl: 'https://synthetic.test/api',
        client: MockClient((request) async {
          auth.person.events.add('request');
          expect(request.url.path, '/api/auth/change-password');
          expect(request.headers['Authorization'], 'Bearer synthetic-token');
          expect(jsonDecode(request.body), {'password': 'Synthetic!1'});
          return http.Response(
            jsonEncode({
              'message': status == 200
                  ? 'Password updated successfully.'
                  : 'Update unavailable.',
            }),
            status,
          );
        }),
      );
      await service.changePassword(
        currentPassword: 'Existing!1',
        newPassword: 'Synthetic!1',
      );
      expect(auth.person.events, ['verify', 'token', 'request', 'session']);
      auth.person.events.clear();
      status = 503;
      await expectLater(
        service.changePassword(
          currentPassword: 'Existing!1',
          newPassword: 'Synthetic!1',
        ),
        throwsA(isA<AuthException>()),
      );
      expect(auth.person.events, ['verify', 'token', 'request']);
      auth.person.events.clear();
      auth.person.reject = true;
      await expectLater(
        service.changePassword(
          currentPassword: 'Wrong!1',
          newPassword: 'Synthetic!1',
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Current password is incorrect.',
          ),
        ),
      );
      expect(auth.person.events, ['verify']);
    },
  );
}
