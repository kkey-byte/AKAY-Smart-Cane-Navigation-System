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
        child: Column(
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
              'No Notifications Yet',
              textAlign: TextAlign.center,
              style: GabayTheme.sectionTitle(context).copyWith(fontSize: 20),
            ),
            const SizedBox(height: 10),
            Text(
              "You're all caught up.\nImportant updates and alerts will appear here.",
              textAlign: TextAlign.center,
              style: GabayTheme.bodyMedium(context).copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
