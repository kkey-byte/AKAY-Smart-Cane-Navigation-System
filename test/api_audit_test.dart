import 'dart:async';
import 'dart:convert';
import 'package:app_mobile/models/user_role.dart';
import 'package:app_mobile/services/app_session_service.dart';
import 'package:app_mobile/services/auth_service.dart';
import 'package:app_mobile/services/destination_search_service.dart';
import 'package:app_mobile/services/map_place_service.dart';
import 'package:app_mobile/services/secure_api.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestUser extends Fake implements User {
  int deletions = 0;
  @override
  String get uid => 'synthetic-user';
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'synthetic-token';
  @override
  Future<void> delete() async {
    deletions++;
  }
}

class TestCredential extends Fake implements UserCredential {
  TestCredential(this.user);
  @override
  final User user;
}

class TestAuth extends Fake implements FirebaseAuth {
  final person = TestUser();
  @override
  User get currentUser => person;
  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async => TestCredential(person);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'navigator and caregiver signup send password for backend hashing',
    () async {
      for (final role in [UserRole.navigator, UserRole.caregiver]) {
        final auth = TestAuth();
        final service = AuthService(
          firebaseAuth: auth,
          baseUrl: 'https://api.example.test/api',
          client: MockClient((request) async {
            final body = jsonDecode(request.body) as Map;
            expect(body['role'], role.backendValue);
            expect(body['password'], 'synthetic-only');
            return http.Response(
              jsonEncode({
                'user': {
                  'user_id': 'synthetic-account',
                  'firebase_uid': auth.person.uid,
                  'email': 'synthetic@example.test',
                  'role': role.backendValue,
                },
              }),
              200,
            );
          }),
        );
        final result = await service.register(
          email: 'synthetic@example.test',
          password: 'synthetic-only',
          role: role,
        );
        expect(result.user.role, role);
        expect(result.token, isNull);
      }
    },
  );
  test(
    'unreachable signup backend reports network failure and preserves Firebase account',
    () async {
      final auth = TestAuth();
      final service = AuthService(
        firebaseAuth: auth,
        baseUrl: 'https://api.example.test/api',
        client: MockClient(
          (_) async => throw http.ClientException('Synthetic network failure'),
        ),
      );
      await expectLater(
        service.register(
          email: 'synthetic@example.test',
          password: 'synthetic-only',
          role: UserRole.navigator,
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'auth_server_unreachable',
          ),
        ),
      );
      expect(auth.person.deletions, 0);
    },
  );
  test(
    'registration sends password and uncertain failure never deletes identity',
    () async {
      final auth = TestAuth();
      final service = AuthService(
        firebaseAuth: auth,
        baseUrl: 'https://api.example.test/api',
        client: MockClient((request) async {
          expect(jsonDecode(request.body)['password'], 'synthetic-only');
          expect(request.headers['Authorization'], 'Bearer synthetic-token');
          return http.Response('{"message":"Unavailable"}', 503);
        }),
      );
      await expectLater(
        service.register(
          email: 'synthetic@example.test',
          password: 'synthetic-only',
          role: UserRole.navigator,
        ),
        throwsA(isA<AuthException>()),
      );
      expect(auth.person.deletions, 0);
    },
  );
  test('session does not persist bearer material in preferences', () async {
    SharedPreferences.setMockInitialValues({
      'authToken': 'legacy-synthetic',
      'local_users_v1': 'legacy-synthetic',
    });
    final session = AppSessionService.instance;
    await session.init();
    await session.loginSession(
      userEmail: 'synthetic@example.test',
      userRole: UserRole.navigator,
      id: 'synthetic',
      token: 'synthetic-credential',
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('authToken'), isNull);
    expect(prefs.getString('local_users_v1'), isNull);
    expect(session.authToken, isNull);
  });
  test(
    'empty search is final; failure is distinct from an empty response',
    () async {
      var calls = 0;
      final search = DestinationSearchService(
        baseUrl: 'https://api.example.test/api',
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/api/search');
          return http.Response(
            calls == 1 ? '[]' : '{}',
            calls == 1 ? 200 : 503,
          );
        }),
      );
      expect(
        await search.search(query: 'synthetic', near: const LatLng(1, 2)),
        isEmpty,
      );
      expect(calls, 1);
      await expectLater(
        search.search(query: 'synthetic', near: const LatLng(1, 2)),
        throwsStateError,
      );
    },
  );
  test(
    'walking routing uses backend by default and rejects missing measurements',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'geometry': {
                  'coordinates': [
                    [2, 1],
                    [3, 2],
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final unavailable = MapPlaceService(client: client, walkingRouteBase: '');
      expect(
        await unavailable.fetchWalkingRoute(
          const LatLng(1, 2),
          const LatLng(2, 3),
        ),
        isNull,
      );
      expect(calls, 1);
      final malformed = MapPlaceService(
        client: client,
        walkingRouteBase: 'https://foot.example.test',
      );
      expect(
        await malformed.fetchWalkingRoute(
          const LatLng(1, 2),
          const LatLng(2, 3),
        ),
        isNull,
      );
      expect(calls, 2);
    },
  );
  test(
    'default walking route uses backend and preserves real geometry',
    () async {
      final service = MapPlaceService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/routing/walk');
          expect(request.url.queryParameters['coordinates'], '2.0,1.0;3.0,2.0');
          return http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [
                {
                  'distance': 120,
                  'duration': 100,
                  'geometry': {
                    'coordinates': [
                      [2, 1],
                      [3, 2],
                    ],
                  },
                  'legs': [],
                },
              ],
            }),
            200,
          );
        }),
      );
      final route = await service.fetchWalkingRoute(
        const LatLng(1, 2),
        const LatLng(2, 3),
      );
      expect(route?.points.length, 2);
      expect(route?.distanceMeters, 120);
      expect(route?.durationSeconds, 100);
    },
  );
  test(
    'one polling request serves duplicate watchers and stops on last cancel',
    () async {
      var calls = 0;
      var revision = 1;
      final api = SecureApi(
        idToken: () async => 'synthetic',
        revision: () => revision,
        bases: ['https://api.example.test/api'],
        client: MockClient((request) async {
          calls++;
          return http.Response('{"connections":[]}', 200);
        }),
      );
      final a = Completer<void>(), b = Completer<void>();
      final first = api.watchGet('/v2/connections').listen((_) => a.complete());
      final second = api
          .watchGet('/v2/connections')
          .listen((_) => b.complete());
      await Future.wait([a.future, b.future]);
      expect(calls, 1);
      await first.cancel();
      await second.cancel();
      revision++;
      await api.watchGet('/v2/connections').first;
      expect(calls, 2);
    },
  );
  test(
    'live polling refreshes, reports revoked access and stops on cancel',
    () async {
      var calls = 0;
      final values = <int>[];
      final revoked = Completer<Object>();
      final api = SecureApi(
        idToken: () async => 'synthetic',
        revision: () => 1,
        bases: ['https://api.example.test/api'],
        client: MockClient((request) async {
          calls++;
          return calls < 3
              ? http.Response('{"sequence":$calls}', 200)
              : http.Response('{"message":"Access revoked"}', 403);
        }),
      );
      final sub = api
          .watchGet(
            '/v2/navigators/synthetic/dashboard',
            interval: const Duration(milliseconds: 20),
          )
          .listen(
            (data) => values.add(data['sequence'] as int),
            onError: (Object error) {
              if (!revoked.isCompleted) revoked.complete(error);
            },
          );
      expect(await revoked.future, isA<SecureApiException>());
      await sub.cancel();
      final callsAtCancel = calls;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(values, [1, 2]);
      expect(calls, callsAtCancel);
    },
  );
}
