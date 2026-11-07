import 'dart:async';
import 'package:app_mobile/models/user_role.dart';
import 'package:app_mobile/services/app_session_service.dart';
import 'package:app_mobile/services/auth_service.dart';
import 'package:app_mobile/services/breadcrumb_service.dart';
import 'package:app_mobile/services/breadcrumb_recorder.dart';
import 'package:app_mobile/services/live_location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountRecorder extends Fake implements BreadcrumbRecorder {
  int closed = 0;
  @override
  Future<void> openAccount(String? uid) async {
    if (uid == null) closed++;
  }
}

class LogoutAuth extends Fake implements FirebaseAuth {
  int attempts = 0;
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    attempts++;
    throw FirebaseAuthException(code: 'invalid-credential');
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    attempts++;
    throw FirebaseAuthException(code: 'operation-not-allowed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final session = AppSessionService.instance;
  Future<void> login(String id) => session.loginSession(
    userEmail: '$id@example.test',
    userRole: UserRole.navigator,
    id: id,
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({'theme': 'dark'});
  });

  test(
    'logout is immediate, single-flight, and never waits for tracking cleanup',
    () async {
      await login('synthetic-first');
      await session.updateProfileCache(
        name: 'Synthetic name',
        profileComplete: true,
      );
      await session.completeOnboarding();
      LiveLocationService.instance.sharingEnabled = true;
      final firebase = Completer<void>(), tracking = Completer<void>();
      var calls = 0;
      final first = session.logout(
        signOut: () {
          calls++;
          return firebase.future;
        },
        cleanupTracking: () => tracking.future,
      );
      final second = session.logout(
        signOut: () async {
          calls++;
        },
      );
      expect(identical(first, second), isTrue);
      expect(session.isLoggedIn, isFalse);
      expect(session.onboardingComplete, isFalse);
      expect(session.profileComplete, isFalse);
      expect(session.role, isNull);
      expect(session.userId, isNull);
      expect(session.displayName, isNull);
      expect(LiveLocationService.instance.sharingEnabled, isFalse);
      expect(calls, 1);
      firebase.complete();
      await first;
      expect(tracking.isCompleted, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isLoggedIn'), isNull);
      expect(prefs.getString('userId'), isNull);
      expect(prefs.getString('userEmail'), isNull);
      expect(prefs.getString('displayName'), isNull);
      expect(prefs.getString('theme'), 'dark');
      tracking.complete();
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('late tracking cleanup cannot close a new account', () async {
    await login('synthetic-first');
    final original = BreadcrumbService.instance.recorder;
    final recorder = AccountRecorder();
    BreadcrumbService.instance.recorder = recorder;
    addTearDown(() => BreadcrumbService.instance.recorder = original);
    final cleanup = Completer<void>();
    await session.logout(
      signOut: () async {},
      cleanupTracking: () => cleanup.future,
    );
    await login('synthetic-second');
    cleanup.complete();
    await Future<void>.delayed(Duration.zero);
    expect(recorder.closed, 0);
    expect(session.userId, 'synthetic-second');
    expect(session.isLoggedIn, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('userId'), 'synthetic-second');
  });

  test(
    'tracking cleanup errors do not prevent Firebase or local sign-out',
    () async {
      await login('synthetic');
      var signedOut = false;
      await session.logout(
        signOut: () async {
          signedOut = true;
        },
        cleanupTracking: () async {
          throw StateError('Synthetic cleanup failure');
        },
      );
      expect(signedOut, isTrue);
      expect(session.isLoggedIn, isFalse);
    },
  );

  test(
    'Firebase failure still clears stored identity and releases the logout barrier',
    () async {
      await login('synthetic');
      await expectLater(
        session.logout(
          signOut: () async {
            throw StateError('Synthetic sign-out failure');
          },
          cleanupTracking: () async {},
        ),
        throwsStateError,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isLoggedIn'), isNull);
      expect(prefs.getString('userId'), isNull);
      expect(session.isLoggedIn, isFalse);
      await session.pendingLogout;
    },
  );

  for (final register in [false, true]) {
    test(
      '${register ? 'registration' : 'login'} waits for previous Firebase sign-out',
      () async {
        await login('synthetic-first');
        final firebase = Completer<void>();
        final logout = session.logout(
          signOut: () => firebase.future,
          cleanupTracking: () async {},
        );
        final auth = LogoutAuth();
        final service = AuthService(firebaseAuth: auth);
        final attempt = register
            ? service.register(
                email: 'synthetic@example.test',
                password: 'synthetic-password',
                role: UserRole.navigator,
              )
            : service.login(
                email: 'synthetic@example.test',
                password: 'synthetic-password',
              );
        final rejected = expectLater(attempt, throwsA(isA<AuthException>()));
        await Future<void>.delayed(Duration.zero);
        expect(auth.attempts, 0);
        firebase.complete();
        await logout;
        await rejected;
        expect(auth.attempts, 1);
      },
    );
  }
}
