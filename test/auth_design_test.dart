import 'dart:io';
import 'dart:ui' as ui;
import 'package:app_mobile/pages/login_page.dart';
import 'package:app_mobile/pages/signup_page.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/auth/gabay_auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:app_mobile/widgets/gabay_logo.dart';
import 'package:app_mobile/widgets/akay_logo_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fontDir = String.fromEnvironment('AKAY_PREVIEW_FONT_DIR');
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (fontDir.isNotEmpty) {
      final text = FontLoader('Roboto')
        ..addFont(
          File(
            '$fontDir/roboto-regular.ttf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        )
        ..addFont(
          File(
            '$fontDir/roboto-medium.ttf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        )
        ..addFont(
          File(
            '$fontDir/roboto-bold.ttf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            '$fontDir/materialicons-regular.otf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await Future.wait([text.load(), icons.load()]);
    }
  });
  for (final signup in [false, true]) {
    for (final large in [false, true]) {
      testWidgets(
        '${signup ? 'Sign Up' : 'Login'} validation and phone layout large=$large',
        (tester) async {
          tester.view.physicalSize = Size(large ? 320 : 390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final preview = GlobalKey();
          final previousShadows = debugDisableShadows;
          if (fontDir.isNotEmpty) {
            debugDisableShadows = false;
            addTearDown(() => debugDisableShadows = previousShadows);
          }
          final baseTheme = large
              ? GabayTheme.darkTheme
              : GabayTheme.lightTheme;
          const buttonText = WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          );
          final renderedTheme = fontDir.isEmpty
              ? baseTheme
              : baseTheme.copyWith(
                  textTheme: baseTheme.textTheme.apply(fontFamily: 'Roboto'),
                  elevatedButtonTheme: ElevatedButtonThemeData(
                    style: baseTheme.elevatedButtonTheme.style!.copyWith(
                      textStyle: buttonText,
                    ),
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: baseTheme.textButtonTheme.style!.copyWith(
                      textStyle: buttonText,
                    ),
                  ),
                );
          await tester.pumpWidget(
            MaterialApp(
              theme: renderedTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: preview,
                child: signup ? const SignupPage() : const LoginPage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(GabayAuthScaffold), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (!large && fontDir.isNotEmpty) {
            await tester.runAsync(
              () => precacheImage(
                MemoryImage(akayLogoBytes),
                tester.element(find.byType(GabayLogo)),
              ),
            );
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              final boundary =
                  preview.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory('build/ui_preview').create(recursive: true);
              await File(
                'build/ui_preview/${signup ? 'signup' : 'login'}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          if (signup) {
            await tester.ensureVisible(find.byType(Checkbox));
            await tester.tap(find.byType(Checkbox));
            await tester.pumpAndSettle();
            expect(find.byType(Dialog), findsOneWidget);
            await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
            await tester.pumpAndSettle();
          }
          final action = find.widgetWithText(
            ElevatedButton,
            signup ? 'Create Account' : 'Login',
          );
          await tester.ensureVisible(action);
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(find.text('Email is required'), findsOneWidget);
          expect(find.text('Password is required'), findsOneWidget);
          if (signup) {
            expect(find.text('Please confirm your password'), findsOneWidget);
          }
          final password = find.byType(TextFormField).at(1);
          await tester.ensureVisible(password);
          await tester.tap(find.byTooltip('Show password'));
          await tester.pumpAndSettle();
          expect(find.byTooltip('Hide password'), findsOneWidget);
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          await tester.ensureVisible(action);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.resetViewInsets();
          debugDisableShadows = previousShadows;
        },
      );
    }
  }
}
