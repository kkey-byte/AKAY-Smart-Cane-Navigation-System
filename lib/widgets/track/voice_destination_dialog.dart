import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/gabay_theme.dart';
import 'destination_speech_input.dart';

String voiceDestinationQuery(String words) => words
    .trim()
    .replaceFirst(
      RegExp(
        r'^(?:search(?: for)?|find|navigate to|take me to)\s+',
        caseSensitive: false,
      ),
      '',
    )
    .trim();

class VoiceDestinationDialog extends StatefulWidget {
  const VoiceDestinationDialog({super.key, this.input});
  final DestinationSpeechInput? input;
  @override
  State<VoiceDestinationDialog> createState() => _VoiceDestinationDialogState();
}

class _VoiceDestinationDialogState extends State<VoiceDestinationDialog>
    with WidgetsBindingObserver {
  late final DestinationSpeechInput _input;
  String _words = '';
  String? _error;
  bool _starting = true, _listening = false;
  int _attempt = 0;
  @override
  void initState() {
    super.initState();
    _input = widget.input ?? DeviceDestinationSpeechInput.instance;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_listen());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _attempt++;
      unawaited(_input.cancel());
      if (mounted) {
        setState(() {
          _starting = false;
          _listening = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _attempt++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_input.cancel());
    super.dispose();
  }

  String _message(String code) {
    if (code.contains('permission') ||
        code.contains('not_allowed') ||
        code.contains('not-allowed')) {
      return 'Allow microphone and speech access in your device or browser settings, then try again.';
    }
    if (code.contains('network')) {
      return 'Speech recognition needs a connection. Check your internet and try again.';
    }
    if (code.contains('no_match') ||
        code.contains('timeout') ||
        code.contains('no-speech')) {
      return 'No speech was recognized. Try again and say a place, such as “Panabo Health Center”.';
    }
    return 'Could not hear you. Check your microphone and try again, or type your destination.';
  }

  Future<void> _listen() async {
    final attempt = ++_attempt;
    setState(() {
      _starting = true;
      _listening = false;
      _words = '';
      _error = null;
    });
    try {
      final ready = await _input.start(
        onText: (words) {
          if (mounted && attempt == _attempt) setState(() => _words = words);
        },
        onStatus: (status) {
          if (mounted && attempt == _attempt) {
            setState(() {
              _listening = status == 'listening';
              if (!_listening) _starting = false;
            });
          }
        },
        onError: (code) {
          if (mounted && attempt == _attempt) {
            setState(() {
              _error = _message(code);
              _starting = false;
              _listening = false;
            });
          }
        },
      );
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _starting = false;
        if (!ready) {
          _error ??=
              'Voice search is unavailable. Check microphone permissions and use a supported device or browser, or type your destination.';
        }
      });
    } catch (_) {
      if (mounted && attempt == _attempt) {
        setState(() {
          _starting = false;
          _listening = false;
          _error = _message('unavailable');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    return AlertDialog(
      scrollable: true,
      title: Row(
        children: [
          const Expanded(child: Text('Voice search')),
          IconButton(
            tooltip: 'Close voice search',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
            color: g.accent,
            size: 36,
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              _starting
                  ? 'Preparing microphone…'
                  : _listening
                  ? 'Listening… Say a destination.'
                  : _words.isEmpty
                  ? 'Say a place or nearby category.'
                  : 'Ready to search',
              textAlign: TextAlign.center,
              style: GabayTheme.bodyMedium(context),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: g.accentTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _words.isEmpty ? 'For example: “hospitals near me”' : _words,
              style: TextStyle(color: g.textPrimary, fontSize: 16),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: g.textSecondary, fontSize: 13),
                ),
              ),
            ),
          if (!_starting && !_listening)
            TextButton.icon(
              onPressed: _listen,
              icon: const Icon(Icons.mic_none_rounded),
              label: const Text('Listen again'),
            ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: voiceDestinationQuery(_words).isEmpty
              ? null
              : () => Navigator.pop(context, voiceDestinationQuery(_words)),
          child: const Text('Search'),
        ),
      ],
    );
  }
}
