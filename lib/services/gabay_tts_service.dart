import 'package:flutter_tts/flutter_tts.dart';

/// Lightweight TTS helper for speaking destination search results.
class GabayTtsService {
  GabayTtsService._();

  static final GabayTtsService instance = GabayTtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _ready = true;
  }

  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _ensureReady();
    await _tts.stop();
    await _tts.speak(trimmed);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
