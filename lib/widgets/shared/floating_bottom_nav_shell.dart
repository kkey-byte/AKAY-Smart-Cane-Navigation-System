import 'package:flutter/material.dart';

/// Layout metrics for the floating bottom navigation bar.
class GabayNavMetrics {
  GabayNavMetrics._();

  static const double horizontalMargin = 20;
  static const double bottomMargin = 16;
  static const double contentClearance = 108;

  /// Bottom inset for overlays (FAB, ETA card) above the floating nav.
  static double overlayBottom(BuildContext context) {
    return contentClearance + MediaQuery.viewPaddingOf(context).bottom * 0.15;
  }
}

/// Transparent wrapper so only the nav pill is visible — not a full-width bar.
class FloatingBottomNavShell extends StatelessWidget {
  const FloatingBottomNavShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: child,
      ),
    );
  }
}
