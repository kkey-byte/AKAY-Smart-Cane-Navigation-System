import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';
import 'gabay_dashboard_backdrop.dart';

/// Standard elevated card used across Caregiver and Navigator screens.
class GabayCard extends StatelessWidget {
  const GabayCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.semanticLabel,
    this.decoration,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final BoxDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final dashboardGlass =
        decoration == null && GabayDashboardBackdrop.active(context);
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: dashboardGlass
          ? null
          : decoration ?? GabayTheme.cardDecoration(context),
      child: child,
    );
    final card = dashboardGlass ? GabayDashboardGlass(child: content) : content;

    if (onTap == null) return card;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: card,
        ),
      ),
    );
  }
}
