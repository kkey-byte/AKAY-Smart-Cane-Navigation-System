import 'package:flutter/material.dart';

/// Shared AKAY text hierarchy. Values remain logical pixels and scale with
/// Flutter's TextScaler; no widget disables or clamps user text scaling.
class GabayTypography {
  GabayTypography._();
  static const double brand = 32;
  static const double hero = 24;
  static const double metric = 24;
  static const double pageTitle = 18;
  static const double subheading = 18;
  static const double sectionTitle = 17;
  static const double cardTitle = 16;
  static const double cardBody = 14;
  static const double body = 14;
  static const double supporting = 13;
  static const double caption = 12;
  // Kept for compact chart axes, not forms, actions, or main body text.
  static const double chartLabel = 10;
  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const semibold = FontWeight.w600;
  static const bold = FontWeight.w700;
}
