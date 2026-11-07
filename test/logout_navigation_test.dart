import 'dart:async';
import 'package:app_mobile/models/user_role.dart';
import 'package:app_mobile/pages/caregiver/caregiver_profile.dart' as caregiver;
import 'package:app_mobile/pages/visually_impaired/visually_impaired_profile.dart'
    as navigator;
import 'package:app_mobile/pages/login_page.dart';
import 'package:app_mobile/services/app_session_service.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/profile/logout_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final session = AppSessionService.instance;
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final role in UserRole.values) {
    testWidgets(
      '${role.name} logout clears the stack before slow sign-out and tracking finish',
      (tester) async {
        session.isLoggedIn = true;
        session.role = role;
        session.email = 'synthetic@example.test';
        session.userId = 'synthetic';
        final root = GlobalKey<NavigatorState>();
        final firebase = Completer<void>(), tracking = Completer<void>();
        var calls = 0;
        Future<void> logout() {
          calls++;
          return session.logout(
            signOut: () => firebase.future,
            cleanupTracking: () => tracking.future,
          );
        }

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: root,
            theme: GabayTheme.lightTheme,
            home: const Scaffold(body: Text('Protected dashboard')),
          ),
        );
        root.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => role == UserRole.caregiver
                ? caregiver.ProfilePage(logout: logout)
                : navigator.VisuallyImpairedProfilePage(logout: logout),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Logout'));
        await tester.tap(find.text('Logout'));
        await tester.pumpAndSettle();
        final confirm = tester
            .widget<LogoutConfirmationDialog>(
              find.byType(LogoutConfirmationDialog),
            )
            .onConfirm;
        confirm();
        confirm(); // Rapid repeated taps while the dialog is closing.
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.text('Protected dashboard'), findsNothing);
        expect(root.currentState!.canPop(), isFalse);
        expect(session.isLoggedIn, isFalse);
        expect(firebase.isCompleted, isFalse);
        expect(tracking.isCompleted, isFalse);
        firebase.complete();
        await tester.pumpAndSettle();
        await session.pendingLogout;
        tracking.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('cancel leaves the signed-in profile and route intact', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: caregiver.ProfilePage(
          logout: () async {
            calls++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Logout'));
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(caregiver.ProfilePage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'a sign-out error cannot strand the user on the authenticated screen',
    (tester) async {
      session.isLoggedIn = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: caregiver.ProfilePage(
            logout: () => session.logout(
              signOut: () async {
                throw StateError('Synthetic failure');
              },
              cleanupTracking: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Logout'));
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Logout').last);
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(session.isLoggedIn, isFalse);
      expect(
        find.textContaining('sign-out could not be confirmed'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
