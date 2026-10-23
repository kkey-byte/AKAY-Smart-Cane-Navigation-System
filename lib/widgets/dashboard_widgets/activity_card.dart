import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

class ActivityCard extends StatelessWidget {
  final Color color;

  final IconData icon;

  final String title;

  final String time;

  final bool showDivider;

  const ActivityCard({
    super.key,

    required this.color,

    required this.icon,

    required this.title,

    required this.time,

    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),

          child: Row(
            children: [
              Container(
                width: 34,

                height: 34,

                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),

                  borderRadius: BorderRadius.circular(11),
                ),

                child: Icon(icon, color: color, size: 21),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      title,

                      style: TextStyle(
                        fontWeight: FontWeight.w500,

                        fontSize: 13,

                        color: g.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'Today • $time',

                      style: TextStyle(
                        color: g.textSecondary,

                        fontSize: 13,

                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (showDivider) Divider(height: 1, color: g.border),
      ],
    );
  }
}

class RecentActivityList extends StatelessWidget {
  const RecentActivityList({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: GabayTheme.cardDecoration(
      context,
    ).copyWith(borderRadius: BorderRadius.circular(18)),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.gabay.accentTint,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            Icons.info_outline,
            color: context.gabay.accent,
            size: 21,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Activity feed unavailable. View recorded trips in Reports.',
            style: TextStyle(fontSize: 13, color: context.gabay.textSecondary),
          ),
        ),
      ],
    ),
  );
}
