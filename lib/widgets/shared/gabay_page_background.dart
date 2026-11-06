import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';
import '../../theme/gabay_visual_tokens.dart';

/// Painted color depth behind page content, without blur or hit-test overlays.
class GabayPageBackground extends StatelessWidget {
  const GabayPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF12233D), Color(0xFF0B1220)]
              : GabayVisualTokens.pageGradient.colors,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(1.1, -.65),
            radius: 1.15,
            colors: [
              context.gabay.accent.withValues(alpha: dark ? .09 : .18),
              Colors.transparent,
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}
