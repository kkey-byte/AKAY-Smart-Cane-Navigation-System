import 'package:app_mobile/models/onboarding_data.dart';
import 'package:app_mobile/pages/onboarding/caregiver_onboarding_page.dart';
import 'package:app_mobile/services/app_session_service.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('caregiver can complete setup without an invite code', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    AppSessionService.instance.setupData = const OnboardingSetupData(
      notificationsGranted: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: const CaregiverOnboardingPage(),
      ),
    );
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('Link Navigator'), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Location Access'), findsOneWidget);
    expect(find.text('Step 2 of 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.text('Step 3 of 3'), findsOneWidget);
    await tester.tap(find.text('Skip tutorial'));
    await tester.pumpAndSettle();
    expect(find.text('Go to Dashboard'), findsOneWidget);
    expect(AppSessionService.instance.setupData.tutorialSkipped, isTrue);
  });
}
