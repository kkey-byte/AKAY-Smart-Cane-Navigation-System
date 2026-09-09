import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

class MapZoomControls extends StatelessWidget {
  const MapZoomControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    this.buttonSize = 52,
    this.gap = 12,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final double buttonSize;
  final double gap;

  static const defaultButtonSize = 52.0;
  static const defaultGap = 12.0;

  static double totalHeight({
    double buttonSize = defaultButtonSize,
    double gap = defaultGap,
  }) {
    return buttonSize + gap + buttonSize;
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Material(
      color: g.surface,
      elevation: 6,
      shadowColor: g.shadow,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: buttonSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: g.border.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ZoomButton(
              icon: Icons.add_rounded,
              tooltip: 'Zoom in',
              size: buttonSize,
              onPressed: onZoomIn,
            ),
            SizedBox(height: gap),
            _ZoomButton(
              icon: Icons.remove_rounded,
              tooltip: 'Zoom out',
              size: buttonSize,
              onPressed: onZoomOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.size,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: g.accent, size: 26),
          ),
        ),
      ),
    );
  }
}
