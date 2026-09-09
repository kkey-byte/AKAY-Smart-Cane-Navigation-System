import 'package:flutter/material.dart';

class BlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final path = Path();

    path.moveTo(size.width * .50, 0);

    path.cubicTo(
      size.width * .82,
      size.height * .02,
      size.width,
      size.height * .20,
      size.width * .96,
      size.height * .48,
    );

    path.cubicTo(
      size.width * .94,
      size.height * .82,
      size.width * .68,
      size.height,
      size.width * .48,
      size.height * .96,
    );

    path.cubicTo(
      size.width * .18,
      size.height * .95,
      0,
      size.height * .76,
      size.width * .04,
      size.height * .48,
    );

    path.cubicTo(
      size.width * .08,
      size.height * .18,
      size.width * .26,
      size.height * .02,
      size.width * .50,
      0,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
