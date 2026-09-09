import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

/// VI home status card — cane battery and walking status (mockup layout).
class ViStatusOverviewCard extends StatelessWidget {
  const ViStatusOverviewCard({
    super.key,
    this.batteryPercent = 78,
    this.statusLabel = 'Walking',
  });

  final int batteryPercent;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: GabayTheme.cardDecoration(context),
      child: Row(
        children: [
          Expanded(child: _BatterySection(percent: batteryPercent)),
          Container(
            width: 1,
            height: 72,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: g.border,
          ),
          Expanded(child: _WalkingSection(statusLabel: statusLabel)),
        ],
      ),
    );
  }
}

class _BatterySection extends StatelessWidget {
  const _BatterySection({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final value = (percent.clamp(0, 100)) / 100.0;

    return Row(
      children: [
        SizedBox(
          width: 68,
          height: 68,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 62,
                height: 62,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 5,
                  backgroundColor: g.accentTint,
                  color: g.accent,
                ),
              ),
              Icon(Icons.bolt_rounded, color: g.accent, size: 26),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: g.accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Cane Battery',
                style: TextStyle(
                  fontSize: 13,
                  color: g.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WalkingSection extends StatelessWidget {
  const _WalkingSection({required this.statusLabel});

  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: g.accentTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.directions_walk_rounded,
                color: g.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 17,
                      color: g.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 13,
                      color: g.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 22,
          child: CustomPaint(painter: _WavePainter(color: g.accent)),
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final centerY = size.height / 2;
    const amplitude = 6.0;
    const wavelength = 28.0;

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
  bool shouldRepaint(_WavePainter oldDelegate) => oldDelegate.color != color;
}
