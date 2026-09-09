import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

class ViStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const ViStatusChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final accent = color ?? g.accent;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: GabayTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 24),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: GabayTheme.labelSmall(context)),
          ],
        ),
      ),
    );
  }
}
