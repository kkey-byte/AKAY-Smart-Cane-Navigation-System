import 'dart:ui' as ui;

import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/dashboard_widgets/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'Action buttons render blue gradients in ${dark ? "dark" : "light"} mode',
      (tester) async {
        var taps = 0;
        final preview = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? GabayTheme.darkTheme : GabayTheme.lightTheme,
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: preview,
                  child: SizedBox(
                    width: 300,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 300,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: () => taps++,
                            child: const Text('Apply'),
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          height: 60,
                          child: FilledButton(
                            onPressed: () => taps++,
                            child: const Text('Continue'),
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          height: 60,
                          child: OutlinedButton(
                            onPressed: () => taps++,
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(
                          width: 300,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: null,
                            child: Text('Disabled'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              preview.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          for (final row in [0, 1]) {
            final top = ((row * 60 + 12) * image.width + 45) * 4;
            final bottom = ((row * 60 + 46) * image.width + 45) * 4;
            expect(pixels.getUint8(top + 2), greaterThan(pixels.getUint8(top)));
            expect(
              pixels.getUint8(bottom + 2),
              greaterThan(pixels.getUint8(bottom)),
            );
          }
          image.dispose();
        });
        for (final label in ['Apply', 'Continue', 'Cancel', 'Disabled']) {
          await tester.tap(find.text(label));
        }
        expect(taps, 3);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('floating navigation fits a narrow phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2.5)),
          child: child!,
        ),
        home: Scaffold(
          bottomNavigationBar: BottomNav(
            currentIndex: 2,
            onIndexChanged: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_outline));
    expect(selected, 3);
    expect(tester.takeException(), isNull);
  });
}
