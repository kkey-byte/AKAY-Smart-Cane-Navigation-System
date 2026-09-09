import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

class LiveStatusCard extends StatelessWidget {
  const LiveStatusCard({
    super.key,
    this.onViewProfile,
  });

  final VoidCallback? onViewProfile;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            "Here's your navigator's current status.",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: g.textSecondary,
              height: 1.35,
            ),
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 18),
              padding: const EdgeInsets.all(20),
              decoration: GabayTheme.cardDecoration(context),
              child: Column(
                children: [
                  _NavigatorHeader(g: g),
                  const SizedBox(height: 18),
                  Divider(color: g.border, height: 1),
                  const SizedBox(height: 20),
                  const _StatusSection(),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: _ViewProfileButton(onTap: onViewProfile),
            ),
          ],
        ),
      ],
    );
  }
}

class _ViewProfileButton extends StatelessWidget {
  const _ViewProfileButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: g.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: g.accent.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View Profile',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: g.accent,
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: g.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigatorHeader extends StatelessWidget {
  const _NavigatorHeader({required this.g});

  final GabayThemeExtension g;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: g.border, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/profile.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: g.accentTint,
                  child: Icon(Icons.person_rounded, color: g.accent, size: 28),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: g.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: g.surface, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Glaisa Regine Mariel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: g.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Navigator',
                style: TextStyle(
                  color: g.textSecondary,
                  fontSize: 14,
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

class _StatusSection extends StatelessWidget {
  const _StatusSection();

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Row(
      children: [
        const Expanded(child: _BatterySection()),
        Container(
          width: 1,
          height: 72,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: g.border,
        ),
        const Expanded(child: _WalkingSection()),
      ],
    );
  }
}

class _BatterySection extends StatelessWidget {
  const _BatterySection();

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

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
                  value: 0.82,
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
                '82%',
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
  const _WalkingSection();

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
                    'Walking',
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
          child: CustomPaint(painter: WavePainter(color: g.accent)),
        ),
      ],
    );
  }
}

class WavePainter extends CustomPainter {
  WavePainter({required this.color});

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
  bool shouldRepaint(WavePainter oldDelegate) => oldDelegate.color != color;
}
