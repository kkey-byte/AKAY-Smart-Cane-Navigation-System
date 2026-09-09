import 'package:flutter/material.dart';

/// Semantic colors that adapt to light / dark mode.
@immutable
class GabayThemeExtension extends ThemeExtension<GabayThemeExtension> {
  const GabayThemeExtension({
    required this.scaffoldBackground,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.heading,
    required this.accent,
    required this.accentTint,
    required this.shadow,
    required this.chipBackground,
    required this.mapPlaceholder,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color scaffoldBackground;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color heading;
  final Color accent;
  final Color accentTint;
  final Color shadow;
  final Color chipBackground;
  final Color mapPlaceholder;
  final Color success;
  final Color warning;
  final Color danger;

  static const light = GabayThemeExtension(
    scaffoldBackground: Color(0xFFF7F8FC),
    surface: Colors.white,
    surfaceElevated: Colors.white,
    border: Color(0xFFE5E7EB),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    heading: Color(0xFF072A67),
    accent: Color(0xFF0A84FF),
    accentTint: Color(0x1F0A84FF),
    shadow: Color(0x0D000000),
    chipBackground: Color(0xFFF7F8FC),
    mapPlaceholder: Color(0xFFE8EEF7),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
  );

  static const dark = GabayThemeExtension(
    scaffoldBackground: Color(0xFF0B1220),
    surface: Color(0xFF1E293B),
    surfaceElevated: Color(0xFF273449),
    border: Color(0xFF475569),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    heading: Color(0xFFE2E8F0),
    accent: Color(0xFF4DA3FF),
    accentTint: Color(0x334DA3FF),
    shadow: Color(0x66000000),
    chipBackground: Color(0xFF334155),
    mapPlaceholder: Color(0xFF1E293B),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
  );

  @override
  GabayThemeExtension copyWith({
    Color? scaffoldBackground,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? heading,
    Color? accent,
    Color? accentTint,
    Color? shadow,
    Color? chipBackground,
    Color? mapPlaceholder,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return GabayThemeExtension(
      scaffoldBackground: scaffoldBackground ?? this.scaffoldBackground,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      heading: heading ?? this.heading,
      accent: accent ?? this.accent,
      accentTint: accentTint ?? this.accentTint,
      shadow: shadow ?? this.shadow,
      chipBackground: chipBackground ?? this.chipBackground,
      mapPlaceholder: mapPlaceholder ?? this.mapPlaceholder,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  GabayThemeExtension lerp(GabayThemeExtension? other, double t) {
    if (other == null) return this;
    return GabayThemeExtension(
      scaffoldBackground:
          Color.lerp(scaffoldBackground, other.scaffoldBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      heading: Color.lerp(heading, other.heading, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      chipBackground: Color.lerp(chipBackground, other.chipBackground, t)!,
      mapPlaceholder: Color.lerp(mapPlaceholder, other.mapPlaceholder, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension GabayContext on BuildContext {
  GabayThemeExtension get gabay =>
      Theme.of(this).extension<GabayThemeExtension>()!;
}

/// Brand colors — use [BuildContext.gabay] for surfaces and text in UI.
class GabayColors {
  GabayColors._();

  static const Color primaryBlue = Color(0xFF0A84FF);
  static const Color darkNavy = Color(0xFF072A67);
  static const Color background = Color(0xFFF7F8FC);
  static const Color cardWhite = Colors.white;
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
}

class GabayTheme {
  GabayTheme._();

  static BoxDecoration cardDecoration(
    BuildContext context, {
    Color? color,
  }) {
    final g = context.gabay;
    return BoxDecoration(
      color: color ?? g.surfaceElevated,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: g.border.withValues(alpha: 0.65)),
      boxShadow: [
        BoxShadow(
          color: g.shadow,
          blurRadius: 25,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  static TextStyle greetingLarge(BuildContext context) => TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: context.gabay.heading,
        height: 1.2,
      );

  static TextStyle greetingSub(BuildContext context) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: context.gabay.textSecondary,
      );

  static TextStyle sectionTitle(BuildContext context) => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: context.gabay.textPrimary,
      );

  static TextStyle bodyLarge(BuildContext context) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: context.gabay.textPrimary,
      );

  static TextStyle bodyMedium(BuildContext context) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: context.gabay.textSecondary,
      );

  static TextStyle labelSmall(BuildContext context) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.gabay.textSecondary,
        letterSpacing: 0.3,
      );

  static ThemeData get lightTheme {
    const ext = GabayThemeExtension.light;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: ext.scaffoldBackground,
      colorScheme: ColorScheme.light(
        primary: GabayColors.primaryBlue,
        onPrimary: Colors.white,
        surface: ext.surface,
        onSurface: ext.textPrimary,
        outline: ext.border,
      ),
      dividerColor: ext.border,
      extensions: const [ext],
      appBarTheme: const AppBarTheme(
        backgroundColor: GabayColors.darkNavy,
        foregroundColor: Colors.white,
      ),
      textTheme: _textTheme(ext),
    );
  }

  static ThemeData get darkTheme {
    const ext = GabayThemeExtension.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ext.scaffoldBackground,
      colorScheme: ColorScheme.dark(
        primary: ext.accent,
        onPrimary: Colors.white,
        surface: ext.surface,
        onSurface: ext.textPrimary,
        outline: ext.border,
      ),
      dividerColor: ext.border,
      extensions: const [ext],
      appBarTheme: AppBarTheme(
        backgroundColor: ext.surface,
        foregroundColor: ext.textPrimary,
      ),
      textTheme: _textTheme(ext),
    );
  }

  static TextTheme _textTheme(GabayThemeExtension ext) {
    return TextTheme(
      headlineMedium: TextStyle(
        color: ext.heading,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: ext.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: ext.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: ext.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(
        color: ext.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: TextStyle(
        color: ext.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
