import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/gabay_theme.dart';
import 'gabay_dashboard_backdrop.dart';

/// A bounded glass layer for floating chrome; content cards remain opaque.
class GabayGlassSurface extends StatelessWidget {
  const GabayGlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.dashboard = false,
  });
  final Widget child;
  final double radius;
  final bool dashboard;
  @override
  Widget build(BuildContext context) =>
      dashboard || Theme.of(context).brightness == Brightness.light
      ? GabayDashboardGlass(radius: radius, child: child)
      : DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: GabayTheme.cardDecoration(context).boxShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.gabay.surface.withValues(alpha: .94),
                      Color.alphaBlend(
                        context.gabay.accent.withValues(alpha: .06),
                        context.gabay.surface,
                      ).withValues(alpha: .86),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: context.gabay.border.withValues(alpha: .7),
                  ),
                ),
                child: child,
              ),
            ),
          ),
        );
}
