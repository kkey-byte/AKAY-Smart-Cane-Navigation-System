import '../../theme/gabay_typography.dart';
import '../shared/gabay_glass_surface.dart';
import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

class NotificationEmptyState extends StatelessWidget {
  const NotificationEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: GabayGlassSurface(
          radius: 28,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: g.accentTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 42,
                    color: g.accent,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Notifications unavailable',
                  textAlign: TextAlign.center,
                  style: GabayTheme.sectionTitle(context).copyWith(
                    fontSize: GabayTypography.sectionTitle,
                    fontWeight: GabayTypography.semibold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "No alert service is connected.",
                  textAlign: TextAlign.center,
                  style: GabayTheme.bodyMedium(context).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
