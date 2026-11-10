import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/track/destination_speech_input.dart';
import 'package:app_mobile/widgets/track/voice_destination_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Speech implements DestinationSpeechInput {
  bool available = true;
  int starts = 0, cancels = 0;
  void Function(String)? text, error, status;
  @override
  Future<bool> start({
    required void Function(String) onText,
    required void Function(String) onStatus,
    required void Function(String) onError,
  }) async {
    starts++;
    text = onText;
    error = onError;
    status = onStatus;
    if (available) onStatus('listening');
    return available;
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

void main() {
  test(
    'Voice search normalizes supported search phrases without starting navigation',
    () {
      expect(
        voiceDestinationQuery(' Find Panabo Health Center '),
        'Panabo Health Center',
      );
      expect(voiceDestinationQuery('navigate to City Hall'), 'City Hall');
      expect(voiceDestinationQuery('hospitals near me'), 'hospitals near me');
      expect(voiceDestinationQuery('  '), '');
    },
  );
  Future<void> open(
    WidgetTester tester,
    _Speech speech,
    void Function(String?) result,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result(
                  await showDialog<String>(
                    context: context,
                    builder: (_) => VoiceDestinationDialog(input: speech),
                  ),
                );
              },
              child: const Text('Open mic'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open mic'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Transcript requires confirmation and closes recognition on Search',
    (tester) async {
      final speech = _Speech();
      String? result;
      await open(tester, speech, (value) => result = value);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Search'))
            .onPressed,
        isNull,
      );
      speech.text!('Find Panabo Health Center');
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Find Panabo Health Center'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Search'));
      await tester.pumpAndSettle();
      expect(result, 'Panabo Health Center');
      expect(speech.cancels, greaterThan(0));
      speech.text!('Late words');
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Permission denial supports retry and cancellation does not submit',
    (tester) async {
      final speech = _Speech();
      String? result;
      await open(tester, speech, (value) => result = value);
      speech.error!('error_permission');
      await tester.pumpAndSettle();
      expect(find.textContaining('Allow microphone'), findsOneWidget);
      await tester.tap(find.text('Listen again'));
      await tester.pumpAndSettle();
      expect(speech.starts, 2);
      speech.text!('Somewhere');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(speech.cancels, greaterThan(0));
    },
  );
  testWidgets('Unsupported recognition leaves typed search available', (
    tester,
  ) async {
    final speech = _Speech()..available = false;
    await open(tester, speech, (_) {});
    expect(find.textContaining('Voice search is unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
