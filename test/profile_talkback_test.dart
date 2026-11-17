import 'package:app_mobile/services/gabay_tts_service.dart';
import 'package:app_mobile/services/screen_reader_service.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/profile/profile_menu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'TalkBack follows Dark mode and toggles at large text, dark=$dark',
      (tester) async {
        var readerEnabled = false;
        var settingsOpened = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          ScreenReaderService.channel,
          (call) async {
            if (call.method == 'isScreenReaderEnabled') return readerEnabled;
            if (call.method == 'openAccessibilitySettings') settingsOpened++;
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            ScreenReaderService.channel,
            null,
          ),
        );
        SharedPreferences.setMockInitialValues({
          GabayTtsService.preferenceKey: false,
        });
        await GabayTtsService.instance.initialize();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (_) async => 1,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel('flutter_tts'),
            null,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? GabayTheme.darkTheme : GabayTheme.lightTheme,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: ProfileSectionCard(
                      title: 'Others',
                      items: profileOthersSection(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getTopLeft(find.text('TalkBack')).dy,
          greaterThan(tester.getTopLeft(find.text('Dark mode')).dy),
        );
        final toggle = find.descendant(
          of: find.byType(ProfileTalkBackToggle),
          matching: find.byType(Switch),
        );
        expect(tester.widget<Switch>(toggle).value, isFalse);
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(settingsOpened, 1);
        // Opening settings alone must not claim that TalkBack is enabled.
        expect(tester.widget<Switch>(toggle).value, isFalse);
        readerEnabled = true;
        ScreenReaderService.instance.didChangeAppLifecycleState(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(toggle).value, isTrue);
        await tester.tap(find.text('TalkBack'));
        await tester.pumpAndSettle();
        expect(settingsOpened, 2);
        expect(tester.widget<Switch>(toggle).value, isTrue);
        readerEnabled = false;
        await ScreenReaderService.instance.refresh();
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(toggle).value, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
