import 'package:app_mobile/models/dashboard_snapshot.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/theme/theme_controller.dart';
import 'package:app_mobile/widgets/dashboard_widgets/activity_card.dart';
import 'package:app_mobile/widgets/dashboard_widgets/bottom_nav.dart';
import 'package:app_mobile/widgets/dashboard_widgets/caregiver_navigation_overview.dart';
import 'package:app_mobile/widgets/dashboard_widgets/dashboard_header.dart';
import 'package:app_mobile/widgets/shared/floating_bottom_nav_shell.dart';
import 'package:app_mobile/widgets/shared/gabay_dashboard_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final caregiver in [true, false]) {
    testWidgets(
      '${caregiver ? "Caregiver" : "Navigator"} dashboard follows live theme changes',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = ThemeController.instance;
        final originalDark = controller.isDarkMode;
        controller.setDarkMode(false);
        addTearDown(() => controller.setDarkMode(originalDark));
        await tester.pumpWidget(
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => MaterialApp(
              theme: GabayTheme.lightTheme,
              darkTheme: GabayTheme.darkTheme,
              themeMode: controller.themeMode,
              home: Builder(
                builder: (context) => Scaffold(
                  body: FloatingBottomNavLayout(
                    navigation: BottomNav(
                      dashboard: true,
                      currentIndex: 0,
                      onIndexChanged: (_) {},
                    ),
                    body: GabayDashboardBackground(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const DashboardHeader(name: 'Test User'),
                            CaregiverNavigationOverview(
                              data: const DashboardSnapshot(
                                uid: 'synthetic',
                                name: 'Test Navigator',
                              ),
                              now: DateTime(2026),
                              onViewMap: () {},
                              showProfileSummary: caregiver,
                              showNavigatorSelector: caregiver,
                            ),
                            Text(
                              'Recent Activity',
                              style: GabayDashboardBackdrop.headingStyle(
                                context,
                              ),
                            ),
                            const RecentActivityList(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Color textColor(String text) =>
            tester.widget<Text>(find.text(text).first).style!.color!;
        expect(textColor('Test User'), GabayDashboardBackdrop.primary);
        expect(textColor('Navigator map'), GabayDashboardBackdrop.primary);
        controller.setDarkMode(true);
        await tester.pumpAndSettle();
        expect(textColor('Test User'), GabayThemeExtension.dark.textPrimary);
        expect(
          textColor('Navigator map'),
          GabayThemeExtension.dark.textPrimary,
        );
        expect(
          textColor('Recent Activity'),
          GabayThemeExtension.dark.textPrimary,
        );
        expect(textColor('Total Distance'), const Color(0xFFCBD5E1));
        expect(textColor('Home'), const Color(0xFFBFDBFE));
        final mapButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'View map'),
        );
        final buttonColor = mapButton.style!.backgroundColor!.resolve({})!;
        expect(buttonColor, GabayColors.primaryBlue);
        expect(1.05 / (buttonColor.computeLuminance() + .05), greaterThan(4.5));
        final canvas = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(GabayDashboardBackground),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final background =
            (canvas.decoration as BoxDecoration).gradient!.colors.first;
        expect(background.computeLuminance(), lessThan(.06));
        final contrast =
            (textColor('Test User').computeLuminance() + .05) /
            (background.computeLuminance() + .05);
        expect(contrast, greaterThan(4.5));
        controller.setDarkMode(false);
        await tester.pumpAndSettle();
        expect(textColor('Test User'), GabayDashboardBackdrop.primary);
        expect(textColor('Navigator map'), GabayDashboardBackdrop.primary);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
