import 'package:flutter/material.dart';

/// Clips the profile header into a navy banner with a central upward notch
/// so the avatar can sit half inside the blue area and half on the body.
class ProfileHeaderClipper extends CustomClipper<Path> {
  const ProfileHeaderClipper({
    this.notchRadius = 56,
    this.sideDrop = 26,
  });

  final double notchRadius;
  final double sideDrop;

  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    final centerX = width / 2;
    final baselineY = height - sideDrop;

    path.moveTo(0, 0);
    path.lineTo(width, 0);
    path.lineTo(width, baselineY);

    path.cubicTo(
      width * 0.84,
      height,
      centerX + notchRadius + 28,
      height,
      centerX + notchRadius,
      baselineY,
    );

    path.arcToPoint(
      Offset(centerX - notchRadius, baselineY),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );

    path.cubicTo(
      centerX - notchRadius - 28,
      height,
      width * 0.16,
      height,
      0,
      baselineY,
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant ProfileHeaderClipper oldClipper) {
    return oldClipper.notchRadius != notchRadius ||
        oldClipper.sideDrop != sideDrop;
  }
}

/// Layout constants shared by the profile header and avatar positioning.
abstract final class ProfileHeaderMetrics {
  static const navyBlue = Color(0xFF0A2463);
  static const notchRadius = 56.0;
  static const avatarSize = 112.0;
  static const avatarBorderWidth = 4.0;
  static const clipHeight = 188.0;
  static const sideDrop = 26.0;

  static double get avatarCenterY => clipHeight - sideDrop;

  static double get avatarTop => avatarCenterY - (avatarSize / 2);

  static double get headerStackHeight => avatarCenterY + (avatarSize / 2);
}
