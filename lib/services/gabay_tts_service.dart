import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Search speech and serialized navigation speech share one native engine.
class GabayTtsService extends ChangeNotifier {
  GabayTtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();
  static final instance = GabayTtsService();
  final FlutterTts _tts;
  static const preferenceKey = 'akay_talkback_enabled';
  bool _enabled = true;
  bool get enabled => _enabled;
  Future<void> _preferenceWrites = Future.value();

  Future<void> initialize() async {
    try {
      _enabled =
          (await SharedPreferences.getInstance()).getBool(preferenceKey) ??
          true;
      notifyListeners();
    } catch (_) {
      // Retain existing speech behavior if local preferences are unavailable.
    }
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    final stopped = value ? Future<void>.value() : stop();
    _preferenceWrites = _preferenceWrites.then((_) async {
      try {
        await (await SharedPreferences.getInstance()).setBool(
          preferenceKey,
          value,
        );
      } catch (_) {
        // Storage failures must not break the current session's switch.
      }
    });
    await Future.wait([stopped, _preferenceWrites]);
  }

  Future<void>? _initializing;
  Future<void> _queue = Future.value();
  Future<void> _stopping = Future.value();
  bool _ready = false;
  bool _navigationReady = false;
  int _generation = 0;
  Completer<void> _cancelled = Completer<void>();

  Future<void> _optional(Future<dynamic> Function() action) async {
    try {
      await action().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Unsupported locale/settings must not prevent default-engine speech.
    }
  }

  Future<void> _ensureReady() async {
    if (_ready) return;
    if (_initializing != null) return _initializing;
    final initializing = _initialize();
    _initializing = initializing;
    try {
      await initializing;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initialize() async {
    for (final locale in ['en-US', 'en-PH', 'en']) {
      try {
        if (await _tts
                    .isLanguageAvailable(locale)
                    .timeout(const Duration(seconds: 5)) ==
                true &&
            await _tts
                    .setLanguage(locale)
                    .timeout(const Duration(seconds: 5)) ==
                1) {
          break;
        }
      } catch (_) {
        // Try the next English locale, then retain the default engine voice.
      }
    }
    await _optional(() => _tts.setSpeechRate(0.45));
    await _optional(() => _tts.setVolume(1));
    await _optional(() => _tts.setPitch(1));
    _ready = true;
  }

  Future<void> _prepareNavigation() async {
    if (_navigationReady) return;
    await _tts.awaitSpeakCompletion(true).timeout(const Duration(seconds: 5));
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _optional(() => _tts.setQueueMode(0));
      await _optional(() => _tts.setAudioAttributesForNavigation());
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _optional(() => _tts.setSharedInstance(true));
      await _optional(
        () => _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.duckOthers],
          IosTextToSpeechAudioMode.voicePrompt,
        ),
      );
    }
    _navigationReady = true;
  }

  /// Serialize using native completion, without stopping each previous cue.
  /// False lets a later GPS event retry instead of breaking navigation.
  Future<bool> speakGuidance(String text) {
    final trimmed = text.trim();
    if (!_enabled || trimmed.isEmpty) return Future.value(false);
    final generation = _generation;
    final cancelled = _cancelled.future;
    final result = Completer<bool>();
    _queue = _queue.then((_) async {
      try {
        await _stopping;
        if (!_enabled || generation != _generation) {
          result.complete(false);
          return;
        }
        await _ensureReady();
        await _prepareNavigation();
        if (!_enabled || generation != _generation) {
          result.complete(false);
          return;
        }
        final spoken = await Future.any([
          _tts.speak(trimmed, focus: true),
          cancelled.then((_) => 0),
        ]).timeout(const Duration(seconds: 30));
        if (spoken != 1 && generation == _generation) _ready = false;
        result.complete(generation == _generation && spoken == 1);
      } catch (_) {
        _ready = false;
        _navigationReady = false;
        if (generation == _generation) await _optional(() => _tts.stop());
        result.complete(false);
      }
    });
    return result.future;
  }

  /// Preserve explicit destination-search playback's replace-current behavior.
  Future<void> speak(String text) async {
    if (!_enabled || text.trim().isEmpty) return;
    await stop();
    final generation = _generation;
    try {
      await _ensureReady();
      if (!_enabled || generation != _generation) return;
      await _tts.speak(text.trim());
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> stop() {
    _generation++;
    _cancelled.complete();
    _cancelled = Completer<void>();
    _queue = Future.value();
    _stopping = _optional(() => _tts.stop());
    return _stopping;
  }
}
