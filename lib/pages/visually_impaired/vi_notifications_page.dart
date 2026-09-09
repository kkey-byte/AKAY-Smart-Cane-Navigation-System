import 'package:flutter/material.dart';

import '../../models/gabay_notification.dart';
import '../../theme/gabay_theme.dart';
import '../../widgets/shared/gabay_detail_page_scaffold.dart';

class ViNotificationsPage extends StatelessWidget {
  const ViNotificationsPage({super.key});

  static final _notifications = [
    GabayNotification(
      id: '1',
      category: NotificationCategory.location,
      title: 'Navigation started',
      description: 'Route to City Hall is active. ETA 12 minutes.',
      createdAt: DateTime(2026, 7, 4, 9, 15),
      destination: NotificationDestination.track,
    ),
    GabayNotification(
      id: '2',
      category: NotificationCategory.connection,
      title: 'Caregiver sent a destination',
      description: 'Mariel Regine shared: Public Market',
      createdAt: DateTime(2026, 7, 3, 14, 30),
      destination: NotificationDestination.track,
    ),
    GabayNotification(
      id: '3',
      category: NotificationCategory.system,
      title: 'Cane battery low',
      description: 'Battery at 20%. Charge your smart cane soon.',
      createdAt: DateTime(2026, 7, 3, 7, 55),
      destination: NotificationDestination.none,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return GabayDetailPageScaffold(
      title: 'Notifications',
      subtitle: 'Alerts, routes, and caregiver updates.',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          for (final n in _notifications)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GabayContentCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _iconColor(g, n.category).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(n.icon, color: _iconColor(g, n.category), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: g.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            n.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: g.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            n.timeAgo,
                            style: TextStyle(fontSize: 11, color: g.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _iconColor(GabayThemeExtension g, NotificationCategory category) {
    return switch (category) {
      NotificationCategory.emergency => g.danger,
      NotificationCategory.location => g.accent,
      NotificationCategory.connection => g.heading,
      NotificationCategory.reports => g.success,
      NotificationCategory.system => g.warning,
    };
  }
}
