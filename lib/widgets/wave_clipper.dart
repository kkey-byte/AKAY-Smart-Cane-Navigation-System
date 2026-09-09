import 'package:flutter/material.dart';

class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();

    // Top
    path.lineTo(0, size.height - 60);

    // First curve
    path.cubicTo(
      size.width * 0.12,
      size.height - 40,
      size.width * 0.18,
      size.height + 5,
      size.width * 0.35,
      size.height,
    );

    // Second curve
    path.cubicTo(
      size.width * 0.55,
      size.height - 5,
      size.width * 0.70,
      size.height - 22,
      size.width * 0.88,
      size.height - 12,
    );

    // End curve (right side goes upward)
    path.cubicTo(
      size.width * 0.97,
      size.height - 10,
      size.width,
      size.height - 45,
      size.width,
      size.height - 80,
    );

    path.lineTo(size.width, 0);

    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
