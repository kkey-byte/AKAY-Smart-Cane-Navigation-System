import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

class ViNavigationBanner extends StatelessWidget {
  const ViNavigationBanner({
    super.key,
    required this.isActive,
    this.destination = 'your selected destination',
    this.eta = 'Unavailable',
    this.distance = 'Unavailable',
    this.onTap,
  });

  final bool isActive;
  final String destination;
  final String eta;
  final String distance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            "Here's your current navigation status.",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: g.textSecondary,
              height: 1.35,
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              padding: const EdgeInsets.all(20),
              decoration: GabayTheme.cardDecoration(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: (isActive ? g.success : g.textSecondary)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: isActive ? g.success : g.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isActive
                                  ? 'Navigation Active'
                                  : 'No Active Route',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isActive ? g.success : g.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (isActive)
                        Icon(
                          Icons.chevron_right_rounded,
                          color: g.textSecondary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: g.accentTint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.flag_rounded,
                          color: g.accent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isActive ? 'Heading to' : 'Set a destination',
                              style: GabayTheme.labelSmall(context),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isActive
                                  ? destination
                                  : 'Tap Track to start navigating',
                              style: GabayTheme.bodyLarge(context),
                            ),
                            if (isActive) ...[
                              const SizedBox(height: 4),
                              Text(
                                'ETA $eta • $distance away',
                                style: GabayTheme.bodyMedium(context).copyWith(
                                  color: g.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
