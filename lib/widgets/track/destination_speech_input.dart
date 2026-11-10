import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

abstract class DestinationSpeechInput {
  Future<bool> start({
    required void Function(String) onText,
    required void Function(String) onStatus,
    required void Function(String) onError,
  });
  Future<void> cancel();
}

/// One device recognizer; callbacks are reassigned for each short search session.
class DeviceDestinationSpeechInput implements DestinationSpeechInput {
  static final instance = DeviceDestinationSpeechInput();
  final _speech = SpeechToText();
  int _epoch = 0;
  void Function(String)? _status, _error;
  Future<void> _closing = Future.value();
  @override
  Future<bool> start({
    required void Function(String) onText,
    required void Function(String) onStatus,
    required void Function(String) onError,
  }) async {
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    final epoch = ++_epoch;
    await _closing;
    if (epoch != _epoch) return false;
    _status = onStatus;
    _error = onError;
    final ready = await _speech.initialize(
      onStatus: (value) => _status?.call(value),
      onError: (value) => _error?.call(value.errorMsg),
      options: [SpeechToText.androidNoBluetooth],
    );
    if (!ready || epoch != _epoch) return false;
    await _speech.listen(
      onResult: (result) {
        if (epoch == _epoch) onText(result.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.search,
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 4),
      ),
    );
    return true;
  }

  @override
  Future<void> cancel() {
    _epoch++;
    _status = null;
    _error = null;
    return _closing = _speech.cancel().catchError((Object _) {});
  }
}
