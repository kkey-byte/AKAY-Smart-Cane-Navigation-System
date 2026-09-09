import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

class VoiceGuidanceButton extends StatelessWidget {
  const VoiceGuidanceButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Semantics(
      button: true,
      label: enabled ? 'Voice guidance on' : 'Voice guidance off',
      child: Material(
        color: enabled ? g.accent : g.surface,
        elevation: 6,
        shadowColor: g.shadow,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              enabled
                  ? Icons.record_voice_over_rounded
                  : Icons.voice_over_off_rounded,
              color: enabled ? Colors.white : g.accent,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
