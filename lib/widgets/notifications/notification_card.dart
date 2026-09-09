import 'package:flutter/material.dart';

import '../../models/gabay_notification.dart';
import '../../theme/gabay_theme.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismissed,
  });

  final GabayNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  Color _iconColor(GabayThemeExtension g) {
    switch (notification.category) {
      case NotificationCategory.emergency:
        return g.danger;
      case NotificationCategory.location:
        return g.accent;
      case NotificationCategory.connection:
        return g.success;
      case NotificationCategory.reports:
        return g.heading;
      case NotificationCategory.system:
        return g.textSecondary;
    }
  }

  Color _iconBackground(GabayThemeExtension g) {
    final color = _iconColor(g);
    return color.withValues(alpha: 0.12);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final iconColor = _iconColor(g);

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: g.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline_rounded, color: g.danger),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: g.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: notification.isRead
                    ? g.border.withValues(alpha: 0.45)
                    : g.accent.withValues(alpha: 0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: g.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _iconBackground(g),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      notification.icon,
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: g.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          notification.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: g.textSecondary,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: g.textSecondary.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: g.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
