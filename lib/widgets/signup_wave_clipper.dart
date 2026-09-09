import 'package:flutter/material.dart';

class SignupWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();

    // Start from top-left
    path.lineTo(0, 55);

    // First smooth wave
    path.cubicTo(
      size.width * 0.10,
      15,
      size.width * 0.25,
      5,
      size.width * 0.40,
      20,
    );

    // Middle wave
    path.cubicTo(
      size.width * 0.55,
      40,
      size.width * 0.68,
      65,
      size.width * 0.82,
      45,
    );

    // Smooth ending (NO POINTY CORNER)
    path.cubicTo(size.width * 0.90, 35, size.width * 0.96, 25, size.width, 60);

    // Right side
    path.lineTo(size.width, size.height);

    // Bottom
    path.lineTo(0, size.height);

    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
