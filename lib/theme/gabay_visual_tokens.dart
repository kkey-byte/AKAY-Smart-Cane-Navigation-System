import 'gabay_typography.dart';
import 'package:flutter/material.dart';

/// Shared presentation values used by both roles; no session or data state.
class GabayVisualTokens {
  GabayVisualTokens._();
  static const ink = Color(0xFF0B2545);
  static const mutedInk = Color(0xFF244264);
  static const primary = Color(0xFF2563EB);
  static const blue = Color(0xFF397BE5);
  static const lavender = Color(0xFF8064D8);
  static const peach = Color(0xFFD97B69);
  static const pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFB9DAFB), Color(0xFFD3E8FF), Color(0xFFEAF4FF)],
  );
  static const glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xA3FFFFFF), Color(0x66FFFFFF), Color(0x8AF5FAFF)],
    stops: [0, .52, 1],
  );
  static const shadow = BoxShadow(
    color: Color(0x18244B78),
    blurRadius: 20,
    offset: Offset(0, 6),
  );
  static BoxShadow shadowFor(bool dark) => dark
      ? const BoxShadow(
          color: Color(0x40203856),
          blurRadius: 20,
          offset: Offset(0, 6),
        )
      : shadow;
  static BoxShadow actionShadow(Color accent) => BoxShadow(
    color: accent.withValues(alpha: .16),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );
  static const sectionHeading = TextStyle(
    color: ink,
    fontSize: GabayTypography.sectionTitle,
    fontWeight: GabayTypography.semibold,
    height: 1.3,
  );
}
