import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/gabay_visual_tokens.dart';
import '../../theme/gabay_theme.dart';

/// Home-only presentation scope; does not change the app's theme or tab state.
class GabayDashboardBackdrop extends InheritedWidget {
  const GabayDashboardBackdrop({super.key, required super.child});

  static bool active(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GabayDashboardBackdrop>() !=
      null;
  static const primary = GabayVisualTokens.ink;
  static const secondary = GabayVisualTokens.mutedInk;
  static const sectionHeading = GabayVisualTokens.sectionHeading;
  static const gradient = GabayVisualTokens.pageGradient;
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color primaryColor(BuildContext context) =>
      isDark(context) ? context.gabay.textPrimary : primary;
  static Color secondaryColor(BuildContext context) =>
      isDark(context) ? const Color(0xFFCBD5E1) : secondary;
  static TextStyle headingStyle(BuildContext context) =>
      sectionHeading.copyWith(color: primaryColor(context));
  static const darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF122B49), Color(0xFF0D1C32), Color(0xFF081321)],
  );

  @override
  bool updateShouldNotify(GabayDashboardBackdrop oldWidget) => false;
}

class GabayDashboardBackground extends StatelessWidget {
  const GabayDashboardBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => GabayDashboardBackdrop(
    child: SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: GabayDashboardBackdrop.isDark(context)
              ? GabayDashboardBackdrop.darkGradient
              : GabayDashboardBackdrop.gradient,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(1.1, -.65),
              radius: 1.15,
              colors: [
                GabayDashboardBackdrop.isDark(context)
                    ? const Color(0x1F60A5FA)
                    : const Color(0x5560A5FA),
                const Color(0x0060A5FA),
              ],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-1.1, .55),
                radius: 1.05,
                colors: [
                  GabayDashboardBackdrop.isDark(context)
                      ? const Color(0x143B82F6)
                      : const Color(0x333B82F6),
                  const Color(0x003B82F6),
                ],
              ),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: GabayDashboardBackdrop.primaryColor(context),
              ),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Bounded blur behind content only, with no filter over the map itself.
class GabayDashboardGlass extends StatelessWidget {
  const GabayDashboardGlass({super.key, required this.child, this.radius = 24});
  final Widget child;
  final double radius;
  static BoxDecoration decoration({double radius = 24, bool dark = false}) =>
      BoxDecoration(
        gradient: dark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xE6253C59), Color(0xD91B2A42)],
              )
            : GabayVisualTokens.glassGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? .14 : .65),
        ),
        boxShadow: [GabayVisualTokens.shadowFor(dark)],
      );
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: decoration(
        radius: radius,
        dark: GabayDashboardBackdrop.isDark(context),
      ).boxShadow,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: decoration(
            radius: radius,
            dark: GabayDashboardBackdrop.isDark(context),
          ).copyWith(boxShadow: const []),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.1,
                colors: [Color(0x0FFFFFFF), Color(0x00FFFFFF)],
              ),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}
