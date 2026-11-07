import 'dart:async';
import 'package:app_mobile/services/gabay_tts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

// flutter_tts guards the iOS method with dart:io Platform.isIOS. Record its
// arguments at the plugin boundary so this check also runs on Windows/Linux.
class RecordingIosTts extends FlutterTts {
  IosTextToSpeechAudioCategory? category;
  IosTextToSpeechAudioMode? mode;
  @override
  Future<dynamic> setIosAudioCategory(
    IosTextToSpeechAudioCategory category,
    List<IosTextToSpeechAudioCategoryOptions> options, [
    IosTextToSpeechAudioMode mode = IosTextToSpeechAudioMode.defaultMode,
  ]) async {
    this.category = category;
    this.mode = mode;
    return 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  late GabayTtsService service;
  late List<MethodCall> calls;
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  String text(MethodCall call) => call.arguments is Map
      ? (call.arguments as Map)['text'] as String
      : call.arguments as String;
  setUp(() {
    calls = [];
    service = GabayTtsService();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  void mock(Future<dynamic> Function(MethodCall)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (handler != null) return handler(call);
          if (call.method == 'isLanguageAvailable') return true;
          return 1;
        });
  }

  test(
    'navigation utterances await completion without cutting off one another',
    () async {
      final completions = [Completer<int>(), Completer<int>()];
      var index = 0;
      mock((call) async {
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'speak') return completions[index++].future;
        return 1;
      });
      final first = service.speakGuidance('Turn right');
      final second = service.speakGuidance('Turn left');
      await flush();
      expect(calls.where((c) => c.method == 'speak').map(text), ['Turn right']);
      expect(calls.where((c) => c.method == 'stop'), isEmpty);
      completions.first.complete(1);
      expect(await first, isTrue);
      await flush();
      expect(calls.where((c) => c.method == 'speak').map(text), [
        'Turn right',
        'Turn left',
      ]);
      completions.last.complete(1);
      expect(await second, isTrue);
    },
  );

  test(
    'stop cancels active and pending instructions without blocking a new route',
    () async {
      final pending = Completer<int>();
      mock((call) async {
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'speak' && text(call) == 'Old turn') {
          return pending.future;
        }
        return 1;
      });
      final active = service.speakGuidance('Old turn');
      final queued = service.speakGuidance('Cancelled turn');
      await flush();
      await service.stop();
      expect(await active, isFalse);
      expect(await queued, isFalse);
      expect(await service.speakGuidance('New turn'), isTrue);
      expect(calls.where((c) => c.method == 'speak').map(text), [
        'Old turn',
        'New turn',
      ]);
      pending.complete(1);
    },
  );

  test(
    'locale fallback and unsupported audio options still allow speech',
    () async {
      mock((call) async {
        if (call.method == 'isLanguageAvailable') {
          return call.arguments == 'en-PH';
        }
        if (call.method == 'setAudioAttributesForNavigation' ||
            call.method == 'setSpeechRate') {
          throw PlatformException(code: 'unsupported');
        }
        return 1;
      });
      expect(await service.speakGuidance('Turn right'), isTrue);
      expect(
        calls.where((c) => c.method == 'setLanguage').single.arguments,
        'en-PH',
      );
      expect(calls.any((c) => c.method == 'speak'), isTrue);
    },
  );

  test(
    'engine defaults work if all locale checks fail and native errors recover',
    () async {
      var attempts = 0;
      mock((call) async {
        if (call.method == 'isLanguageAvailable') {
          throw PlatformException(code: 'locale');
        }
        if (call.method == 'speak' && attempts++ == 0) {
          throw PlatformException(code: 'engine');
        }
        return 1;
      });
      expect(await service.speakGuidance('Turn right'), isFalse);
      expect(await service.speakGuidance('Turn right'), isTrue);
      expect(calls.where((c) => c.method == 'setLanguage'), isEmpty);
    },
  );

  test(
    'Android uses navigation attributes; iOS uses playback voice-prompt session',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      mock(null);
      expect(await service.speakGuidance('Turn right'), isTrue);
      expect(
        calls.any((c) => c.method == 'setAudioAttributesForNavigation'),
        isTrue,
      );
      expect(
        calls.where((c) => c.method == 'setQueueMode').single.arguments,
        0,
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final ios = RecordingIosTts();
      service = GabayTtsService(tts: ios);
      calls.clear();
      expect(await service.speakGuidance('Turn left'), isTrue);
      expect(calls.any((c) => c.method == 'setSharedInstance'), isTrue);
      expect(ios.category, IosTextToSpeechAudioCategory.playback);
      expect(ios.mode, IosTextToSpeechAudioMode.voicePrompt);
    },
  );

  testWidgets(
    'missing native completion times out without blocking later speech',
    (tester) async {
      service = GabayTtsService();
      final stalled = Completer<int>();
      var attempts = 0;
      mock((call) async {
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'speak' && attempts++ == 0) return stalled.future;
        return 1;
      });
      final first = service.speakGuidance('Stalled turn');
      final second = service.speakGuidance('Next turn');
      for (
        var i = 0;
        i < 30 && !calls.any((call) => call.method == 'speak');
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(calls.where((call) => call.method == 'speak'), hasLength(1));
      await tester.pump(const Duration(seconds: 31));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(await first, isFalse);
      expect(await second, isTrue);
      expect(calls.any((call) => call.method == 'stop'), isTrue);
      stalled.complete(1);
    },
  );
}
