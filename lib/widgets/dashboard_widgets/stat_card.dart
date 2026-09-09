import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String unit;
  final Color color;

  const StatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: GabayTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: g.textPrimary,
              ),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: g.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 28,
            child: CustomPaint(painter: StatWavePainter(color: color)),
          ),
        ],
      ),
    );
  }
}

class StatWavePainter extends CustomPainter {
  StatWavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final centerY = size.height / 2;
    const amplitude = 8.0;
    const wavelength = 36.0;

    for (double x = 0; x <= size.width; x += 1) {
      final y = centerY + amplitude * sin(2 * pi * x / wavelength);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(StatWavePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
