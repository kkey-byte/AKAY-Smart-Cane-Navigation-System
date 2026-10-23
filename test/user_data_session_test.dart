import 'package:app_mobile/models/patient_profile.dart';
import 'package:app_mobile/services/destination_search_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:app_mobile/models/user_role.dart';
import 'package:app_mobile/services/app_session_service.dart';
import 'package:app_mobile/services/profile_service.dart';
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
  http.Response profile(String id, {String? name}) => http.Response(
    jsonEncode({
      'user': {
        'userId': id,
        'email': '$id@example.test',
        'role': 'visually_impaired',
        'name': name,
      },
      'patientProfile': {},
    }),
    200,
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('account switch clears cached profile and onboarding', () async {
    await login('first');
    await session.updateProfileCache(
      name: 'Synthetic First',
      phone: 'test',
      profilePicture: 'old',
      profileComplete: true,
    );
    await session.completeOnboarding();
    await login('second');
    expect(session.displayName, isNull);
    expect(session.phone, isNull);
    expect(session.profilePicture, isNull);
    expect(session.profileComplete, isFalse);
    expect(session.onboardingComplete, isFalse);
    expect(session.setupData.emergencyContacts, isEmpty);
  });

  test('late profile response cannot overwrite another account', () async {
    await login('first');
    final response = Completer<http.Response>();
    final service = ProfileService(
      client: MockClient((_) => response.future),
      firebaseUid: () => null,
      idToken: () async => 'synthetic-id-token',
    );
    final pending = service.fetchProfile();
    final rejected = expectLater(pending, throwsA(isA<ProfileException>()));
    await login('second');
    response.complete(profile('first', name: 'Synthetic First'));
    await rejected;
    expect(session.userId, 'second');
    expect(session.displayName, isNull);
  });

  test('logout invalidates pending profile and signs out Firebase', () async {
    await login('first');
    final response = Completer<http.Response>();
    final service = ProfileService(
      client: MockClient((_) => response.future),
      firebaseUid: () => null,
      idToken: () async => 'synthetic-id-token',
    );
    final rejected = expectLater(
      service.fetchProfile(),
      throwsA(isA<ProfileException>()),
    );
    var signedOut = false;
    await session.logout(
      signOut: () async {
        signedOut = true;
      },
    );
    response.complete(profile('first', name: 'Synthetic First'));
    await rejected;
    expect(signedOut, isTrue);
    expect(session.isLoggedIn, isFalse);
    expect(session.displayName, isNull);
  });

  test(
    'account change while obtaining token prevents sending old profile edits',
    () async {
      await login('first');
      final token = Completer<String?>();
      var sent = 0;
      final service = ProfileService(
        client: MockClient((_) async {
          sent++;
          return profile('second');
        }),
        firebaseUid: () => null,
        idToken: () => token.future,
      );
      final rejected = expectLater(
        service.saveProfile(
          name: 'Synthetic Old',
          phone: 'test',
          patient: const PatientProfile(),
        ),
        throwsA(isA<ProfileException>()),
      );
      await login('second');
      token.complete('synthetic-old-token');
      await rejected;
      expect(sent, 0);
    },
  );

  test('recent searches belong only to their account', () async {
    final search = DestinationSearchService.instance;
    await login('first');
    await search.saveRecentQuery('Synthetic destination');
    await login('second');
    expect(await search.loadRecentQueries(), isEmpty);
    await login('first');
    expect(await search.loadRecentQueries(), ['Synthetic destination']);
  });

  test('mismatched profile identity is rejected', () async {
    await login('second');
    final service = ProfileService(
      client: MockClient((_) async => profile('other')),
      firebaseUid: () => null,
      idToken: () async => 'synthetic-id-token',
    );
    await expectLater(service.fetchProfile(), throwsA(isA<ProfileException>()));
    expect(session.displayName, isNull);
  });

  test(
    'successful refresh clears missing fields instead of retaining old data',
    () async {
      await login('second');
      await session.updateProfileCache(
        name: 'Old',
        phone: 'Old',
        profilePicture: 'Old',
      );
      final service = ProfileService(
        client: MockClient((_) async => profile('second')),
        firebaseUid: () => null,
        idToken: () async => 'synthetic-id-token',
      );
      await service.fetchProfile();
      expect(session.displayName, isEmpty);
      expect(session.phone, isEmpty);
      expect(session.profilePicture, isEmpty);
    },
  );
}
