import 'package:app_mobile/pages/signup_page.dart';
import 'package:app_mobile/pages/shared/terms_conditions_page.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final large in [false, true]) {
    testWidgets(
      'Terms require confirmation and can be dismissed large=$large',
      (tester) async {
        tester.view.physicalSize = Size(large ? 320 : 390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: GabayTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
              child: child!,
            ),
            home: const SignupPage(),
          ),
        );
        await tester.pumpAndSettle();
        final checkbox = find.byType(Checkbox);
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        expect(find.byType(TermsConditionsContent), findsOneWidget);
        expect(tester.widget<Checkbox>(checkbox).value, isFalse);
        await tester.tap(find.byTooltip('Close terms'));
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(checkbox).value, isFalse);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('7. Changes to Terms'));
        expect(tester.takeException(), isNull);
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(tester.widget<Checkbox>(checkbox).value, isTrue);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(checkbox).value, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
