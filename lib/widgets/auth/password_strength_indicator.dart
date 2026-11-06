import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

/// Display-only feedback; each form retains its existing validation rules.
class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final password = value.text;
        if (password.isEmpty) return const SizedBox.shrink();
        final strong =
            password.runes.length >= 8 &&
            RegExp(r'[A-Z]').hasMatch(password) &&
            RegExp(r'[^a-zA-Z0-9\s]').hasMatch(password);
        final g = context.gabay;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Semantics(
            liveRegion: true,
            child: Text(
              strong ? 'Strong password' : 'Weak password',
              style: TextStyle(
                color: strong ? g.success : g.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}
