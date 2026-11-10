import 'package:app_mobile/pages/landing_page.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'landing survives narrow layout and short viewport, dark=$dark',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final size in [
          const Size(1.5, 720),
          const Size(320, 400),
          const Size(390, 844),
        ]) {
          for (final scale in [1.0, 2.0]) {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? GabayTheme.darkTheme : GabayTheme.lightTheme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: const LandingPage(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$size at text scale $scale',
            );
            expect(find.text('Login'), findsOneWidget);
            expect(find.text('Get Started'), findsOneWidget);
          }
        }
      },
    );
  }
}
