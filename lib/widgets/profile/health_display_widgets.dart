import 'package:flutter/material.dart';
import '../../theme/gabay_theme.dart';
import '../../theme/gabay_typography.dart';
import '../shared/gabay_card.dart';
import '../shared/gabay_accent_icon.dart';

class GabayHealthIcon extends StatelessWidget {
  const GabayHealthIcon({super.key, required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: context.gabay.accentTint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: GabayAccentIcon(icon, color: context.gabay.accent, size: 24),
  );
}

class GabayHealthOverviewCard extends StatelessWidget {
  const GabayHealthOverviewCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.unit = '',
  });
  final String label, value, unit;
  final IconData icon;
  @override
  Widget build(BuildContext context) => GabayCard(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
    child: Column(
      children: [
        GabayHealthIcon(icon: icon),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.gabay.textSecondary,
            fontSize: GabayTypography.caption,
          ),
        ),
        const SizedBox(height: 5),
        Text.rich(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          TextSpan(
            text: value,
            children: [
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(fontSize: GabayTypography.chartLabel),
                ),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.gabay.accent,
            fontSize: value == 'Not provided' ? 13 : 17,
            fontWeight: GabayTypography.regular,
          ),
        ),
      ],
    ),
  );
}

class GabayHealthSection extends StatelessWidget {
  const GabayHealthSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => GabayCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GabayHealthIcon(icon: icon),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: context.gabay.textPrimary,
                  fontWeight: GabayTypography.regular,
                  fontSize: GabayTypography.body,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class GabayHealthDetail extends StatelessWidget {
  const GabayHealthDetail({
    super.key,
    required this.label,
    required this.value,
  });
  final String label, value;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final caption = Text(
        label,
        style: TextStyle(
          color: context.gabay.textSecondary,
          fontSize: GabayTypography.supporting,
        ),
      );
      final content = Text(
        value,
        style: TextStyle(
          color: context.gabay.accent,
          fontSize: GabayTypography.supporting,
        ),
      );
      if (MediaQuery.textScalerOf(context).scale(13) > 20) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [caption, const SizedBox(height: 6), content],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: caption),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: content),
          ),
        ],
      );
    },
  );
}
