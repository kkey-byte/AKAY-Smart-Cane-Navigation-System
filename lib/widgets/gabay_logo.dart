import 'dart:math';
import 'package:flutter/material.dart';

class GabayLogo extends StatelessWidget {
  final double size;
  final Color color;

  const GabayLogo({
    super.key,
    this.size = 100,
    this.color = const Color(0xFF0958C7), // Brand Blue
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: GabayLogoPainter(color: color),
      ),
    );
  }
}

class GabayLogoPainter extends CustomPainter {
  final Color color;

  GabayLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw concentric location pin shapes rotated clockwise by 45 degrees
    // (so the tip points to the bottom-left / 135 degrees)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(pi / 4);

    final outerRadius = size.width * 0.34;
    final outerL = outerRadius * 1.45;
    final outerPath = _createPinPath(outerRadius, outerL);
    canvas.drawPath(outerPath, paint);

    final innerRadius = size.width * 0.20;
    final innerL = innerRadius * 1.45;
    final innerPath = _createPinPath(innerRadius, innerL);
    canvas.drawPath(innerPath, paint);

    canvas.restore();

    // Draw the upright mountain peaks in the center
    final mountainPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final mountainPath = Path();
    final scale = size.width;

    // Adjust mountain dimensions to fit perfectly inside innerRadius
    final baseY = center.dy + scale * 0.06;
    final peak1y = center.dy - scale * 0.08; // Left (taller) peak
    final peak1x = center.dx - scale * 0.04;
    
    final peak2y = center.dy - scale * 0.01; // Right (shorter) peak
    final peak2x = center.dx + scale * 0.07;
    
    final leftX = center.dx - scale * 0.12;
    final rightX = center.dx + scale * 0.14;
    final midX = center.dx + scale * 0.02;

    mountainPath.moveTo(leftX, baseY);
    mountainPath.lineTo(peak1x, peak1y);
    mountainPath.lineTo(midX, baseY + (peak2y - baseY) * 0.5); // Valley
    mountainPath.lineTo(peak2x, peak2y);
    mountainPath.lineTo(rightX, baseY);
    mountainPath.close();

    canvas.drawPath(mountainPath, mountainPaint);
  }

  Path _createPinPath(double r, double L) {
    final path = Path();
    final alpha = acos(r / L);
    final rightAngle = pi / 2 - alpha;

    final tx1 = r * cos(rightAngle);
    final ty1 = r * sin(rightAngle);

    final sweepAngle = -(2 * pi - 2 * alpha);

    path.moveTo(tx1, ty1);
    path.arcTo(
      Rect.fromCircle(center: Offset.zero, radius: r),
      rightAngle,
      sweepAngle,
      false,
    );
    path.lineTo(0, L);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
