import 'package:app_mobile/pages/shared/change_password_page.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_mobile/services/auth_service.dart';

class TestPasswordAuth extends Fake implements AuthService {
  int updates = 0;
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    expect(currentPassword, 'Existing-example');
    expect(newPassword, 'Abcdef!1');
    updates++;
  }
}

void main() {
  testWidgets(
    'Requires current password, password rules, and matching confirmation',
    (tester) async {
      final auth = TestPasswordAuth();
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: ChangePasswordPage(authService: auth),
        ),
      );
      final fields = find.byType(TextFormField);
      final submit = find.widgetWithText(ElevatedButton, 'Apply Changes');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(find.text('Current Password is required'), findsOneWidget);
      expect(find.text('New Password is required'), findsOneWidget);
      expect(find.text('Confirm Password is required'), findsOneWidget);
      await tester.enterText(fields.at(0), 'Existing-example');
      await tester.enterText(fields.at(1), 'short');
      await tester.enterText(fields.at(2), 'different');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(find.text('Meet all password requirements below'), findsOneWidget);
      expect(find.text('Passwords do not match'), findsOneWidget);
      await tester.enterText(fields.at(1), 'Abcdef!1');
      await tester.enterText(fields.at(2), 'Abcdef!1');
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(find.text('Password updated successfully.'), findsOneWidget);
      expect(auth.updates, 1);
      expect(
        tester.widget<TextFormField>(fields.at(0)).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'Password visibility is independent and large text remains scrollable',
    (tester) async {
      tester.view.physicalSize = const Size(374, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const ChangePasswordPage(),
          ),
        ),
      );
      await tester.ensureVisible(find.byTooltip('Show current password'));
      await tester.tap(find.byTooltip('Show current password'));
      await tester.pump();
      final fields = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .toList();
      expect(fields[0].obscureText, isFalse);
      expect(fields[1].obscureText, isTrue);
      expect(fields[2].obscureText, isTrue);
      await tester.ensureVisible(find.byType(ElevatedButton));
      expect(tester.takeException(), isNull);
    },
  );
}
