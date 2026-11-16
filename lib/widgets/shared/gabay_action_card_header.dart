import 'package:flutter/material.dart';
import '../../theme/gabay_theme.dart';

class GabayActionCardHeader extends StatelessWidget {
  const GabayActionCardHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title, description;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.gabay.accentTint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 24, color: context.gabay.accent),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GabayTheme.sectionTitle(context).copyWith(fontSize: 15),
            ),
            const SizedBox(height: 5),
            Text(
              description,
              style: GabayTheme.bodyMedium(context).copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    ],
  );
}
