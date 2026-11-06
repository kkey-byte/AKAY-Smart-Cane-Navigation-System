import 'gabay_typography.dart';
import 'gabay_visual_tokens.dart';
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
    scaffoldBackground: Color(0xFFEFF6FF),
    surface: Colors.white,
    surfaceElevated: Colors.white,
    border: Color(0xFFD3E2F5),
    textPrimary: GabayVisualTokens.ink,
    textSecondary: GabayVisualTokens.mutedInk,
    heading: Color(0xFF123B70),
    accent: Color(0xFF2563EB),
    accentTint: Color(0xFFDBEAFE),
    shadow: Color(0x18244B78),
    chipBackground: Color(0xFFEFF6FF),
    mapPlaceholder: Color(0xFFEAF0FB),
    success: Color(0xFF16805D),
    warning: Color(0xFF9A650A),
    danger: Color(0xFFCB354C),
  );

  static const dark = GabayThemeExtension(
    scaffoldBackground: Color(0xFF0B1220),
    surface: Color(0xFF1E293B),
    surfaceElevated: Color(0xFF273449),
    border: Color(0xFF475569),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    heading: Color(0xFFD3E2F5),
    accent: Color(0xFF4DA3FF),
    accentTint: Color(0x334DA3FF),
    shadow: Color(0x40203856),
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
      scaffoldBackground: Color.lerp(
        scaffoldBackground,
        other.scaffoldBackground,
        t,
      )!,
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

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color darkNavy = Color(0xFF123B70);
  static const Color background = Color(0xFFEFF6FF);
  static const Color cardWhite = Colors.white;
  static const Color textPrimary = Color(0xFF172554);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color success = Color(0xFF16805D);
  static const Color warning = Color(0xFF9A650A);
  static const Color danger = Color(0xFFCB354C);
}

/// Shared dimensions for AKAY surfaces and controls.
class GabayMetrics {
  GabayMetrics._();
  static const double screenPadding = 20;
  static const double cardPadding = 16;
  static const double sectionGap = 20;
  static const double itemGap = 12;
  static const double cardRadius = 24;
  static const double controlRadius = 18;
  static const double buttonHeight = 48;
}

class GabayTheme {
  GabayTheme._();
  static const actionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF2149C6)],
  );
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF123B70)],
  );

  static ButtonStyle get _actionButtonStyle => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(
      Size(48, GabayMetrics.buttonHeight),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(
        fontSize: GabayTypography.body,
        fontWeight: GabayTypography.medium,
      ),
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.disabled) ? Colors.white70 : Colors.white,
    ),
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GabayMetrics.controlRadius),
      ),
    ),
    backgroundBuilder: (context, states, child) {
      final disabled = states.contains(WidgetState.disabled);
      final button = context.widget as ButtonStyleButton;
      final localColor = button.style?.backgroundColor?.resolve(states);
      final solid = localColor != null && localColor.a > 0;
      return DecoratedBox(
        decoration: ShapeDecoration(
          shape:
              button.style?.shape?.resolve(states) ??
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GabayMetrics.controlRadius),
              ),
          gradient: disabled || solid ? null : actionGradient,
          color: disabled
              ? Theme.of(context).disabledColor
              : solid
              ? localColor
              : null,
          shadows: disabled
              ? null
              : [GabayVisualTokens.actionShadow(context.gabay.accent)],
        ),
        child: child,
      );
    },
  );

  static ButtonStyle secondaryButtonStyle(BuildContext context) =>
      OutlinedButton.styleFrom(
        minimumSize: const Size(48, GabayMetrics.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        backgroundColor: context.gabay.surface,
        foregroundColor: context.gabay.heading,
        side: BorderSide(color: context.gabay.border),
        textStyle: const TextStyle(
          fontSize: GabayTypography.body,
          fontWeight: GabayTypography.medium,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GabayMetrics.controlRadius),
        ),
      ).copyWith(
        backgroundBuilder: (context, states, child) =>
            child ?? const SizedBox.shrink(),
      );

  static ButtonStyle destructiveButtonStyle(BuildContext context) =>
      FilledButton.styleFrom(
        backgroundColor: context.gabay.danger.withValues(alpha: .10),
        foregroundColor: context.gabay.danger,
      );

  static BoxDecoration cardDecoration(BuildContext context, {Color? color}) {
    final g = context.gabay;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: color ?? g.surfaceElevated,
      gradient: color != null
          ? null
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [g.surfaceElevated, g.surface]
                  : GabayVisualTokens.glassGradient.colors,
            ),
      borderRadius: BorderRadius.circular(GabayMetrics.cardRadius),
      border: Border.all(
        color: dark
            ? g.border.withValues(alpha: .65)
            : Colors.white.withValues(alpha: .65),
      ),
      boxShadow: [GabayVisualTokens.shadowFor(dark)],
    );
  }

  static TextStyle greetingLarge(BuildContext context) => TextStyle(
    fontSize: GabayTypography.metric,
    fontWeight: GabayTypography.medium,
    color: context.gabay.heading,
    height: 1.3,
  );
  static TextStyle greetingSub(BuildContext context) => TextStyle(
    fontSize: GabayTypography.body,
    fontWeight: GabayTypography.regular,
    color: context.gabay.textSecondary,
    height: 1.4,
  );
  static TextStyle sectionTitle(BuildContext context) => TextStyle(
    fontSize: GabayTypography.sectionTitle,
    fontWeight: GabayTypography.semibold,
    color: context.gabay.textPrimary,
  );
  static TextStyle bodyLarge(BuildContext context) => TextStyle(
    fontSize: GabayTypography.cardTitle,
    fontWeight: GabayTypography.regular,
    color: context.gabay.textPrimary,
    height: 1.4,
  );
  static TextStyle bodyMedium(BuildContext context) => TextStyle(
    fontSize: GabayTypography.body,
    fontWeight: GabayTypography.regular,
    color: context.gabay.textSecondary,
    height: 1.4,
  );
  static TextStyle labelSmall(BuildContext context) => TextStyle(
    fontSize: GabayTypography.caption,
    fontWeight: GabayTypography.regular,
    color: context.gabay.textSecondary,
    height: 1.3,
  );

  static ThemeData get lightTheme =>
      _theme(GabayThemeExtension.light, Brightness.light);
  static ThemeData get darkTheme =>
      _theme(GabayThemeExtension.dark, Brightness.dark);
  static ThemeData _theme(GabayThemeExtension ext, Brightness brightness) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GabayMetrics.cardRadius),
      side: BorderSide(color: ext.border.withValues(alpha: .65)),
    );
    final secondary = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(48, GabayMetrics.buttonHeight),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontSize: GabayTypography.body,
          fontWeight: GabayTypography.medium,
        ),
      ),
      foregroundColor: WidgetStatePropertyAll(ext.heading),
      backgroundColor: WidgetStatePropertyAll(ext.surface),
      side: WidgetStatePropertyAll(BorderSide(color: ext.border)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GabayMetrics.controlRadius),
        ),
      ),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: ext.scaffoldBackground,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: ext.accent,
            brightness: brightness,
          ).copyWith(
            primary: ext.accent,
            onPrimary: Colors.white,
            surface: ext.surface,
            onSurface: ext.textPrimary,
            outline: ext.border,
            error: ext.danger,
          ),
      extensions: [ext],
      dividerColor: ext.border,
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ext.accent
              : brightness == Brightness.dark
              ? const Color(0xFF334155)
              : const Color(0xFFB6C9E4),
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ext.accent
              : ext.textSecondary,
        ),
        trackOutlineWidth: const WidgetStatePropertyAll(1.5),
      ),
      checkboxTheme: CheckboxThemeData(
        side: BorderSide(color: ext.textSecondary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ext.accent,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _actionButtonStyle),
      filledButtonTheme: FilledButtonThemeData(style: _actionButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: secondary),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: ext.accent,
          textStyle: const TextStyle(
            fontSize: GabayTypography.body,
            fontWeight: GabayTypography.medium,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: ext.accent,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ext.heading,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: ext.heading,
          fontSize: GabayTypography.pageTitle,
          fontWeight: GabayTypography.semibold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ext.chipBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(
          color: ext.textSecondary,
          fontSize: GabayTypography.body,
        ),
        hintStyle: TextStyle(
          color: ext.textSecondary,
          fontSize: GabayTypography.body,
        ),
        errorStyle: TextStyle(
          color: ext.danger,
          fontSize: GabayTypography.caption,
        ),
        prefixIconColor: ext.accent,
        suffixIconColor: ext.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GabayMetrics.controlRadius),
          borderSide: BorderSide(color: ext.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GabayMetrics.controlRadius),
          borderSide: BorderSide(color: ext.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GabayMetrics.controlRadius),
          borderSide: BorderSide(color: ext.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GabayMetrics.controlRadius),
          borderSide: BorderSide(color: ext.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GabayMetrics.controlRadius),
          borderSide: BorderSide(color: ext.danger, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ext.surface,
        shadowColor: ext.shadow,
        surfaceTintColor: ext.accentTint,
        shape: shape,
        elevation: 4,
        titleTextStyle: TextStyle(
          color: ext.heading,
          fontSize: GabayTypography.pageTitle,
          fontWeight: GabayTypography.medium,
        ),
        contentTextStyle: TextStyle(
          color: ext.textSecondary,
          fontSize: GabayTypography.body,
          height: 1.4,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ext.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: ext.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ext.heading,
        contentTextStyle: TextStyle(
          color: brightness == Brightness.light
              ? Colors.white
              : ext.scaffoldBackground,
          fontSize: GabayTypography.body,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: ext.heading,
          fontSize: GabayTypography.metric,
          fontWeight: GabayTypography.semibold,
          height: 1.25,
        ),
        titleLarge: TextStyle(
          color: ext.heading,
          fontSize: GabayTypography.subheading,
          fontWeight: GabayTypography.medium,
        ),
        titleMedium: TextStyle(
          color: ext.textPrimary,
          fontSize: GabayTypography.cardTitle,
          fontWeight: GabayTypography.medium,
        ),
        titleSmall: TextStyle(
          color: ext.textPrimary,
          fontSize: GabayTypography.body,
          fontWeight: GabayTypography.medium,
        ),
        bodyLarge: TextStyle(
          color: ext.textPrimary,
          fontSize: GabayTypography.cardTitle,
          fontWeight: GabayTypography.regular,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          color: ext.textPrimary,
          fontSize: GabayTypography.body,
          fontWeight: GabayTypography.regular,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          color: ext.textSecondary,
          fontSize: GabayTypography.caption,
          fontWeight: GabayTypography.regular,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          color: ext.textPrimary,
          fontSize: GabayTypography.body,
          fontWeight: GabayTypography.medium,
        ),
        labelMedium: TextStyle(
          color: ext.textSecondary,
          fontSize: GabayTypography.caption,
          fontWeight: GabayTypography.regular,
        ),
        labelSmall: TextStyle(
          color: ext.textSecondary,
          fontSize: GabayTypography.caption,
          fontWeight: GabayTypography.regular,
        ),
      ),
    );
  }
}
