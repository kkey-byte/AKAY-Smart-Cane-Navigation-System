import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    this.onNotificationTap,
    this.unreadCount = 0,
    this.greeting = 'Hello, Welcome back!',
    this.name = 'User',
    this.avatarAsset,
  });

  final VoidCallback? onNotificationTap;
  final int unreadCount;
  final String greeting;
  final String name;
  final String? avatarAsset;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: g.border, width: 2),
            color: g.accentTint,
          ),
          clipBehavior: Clip.antiAlias,
          child: avatarAsset == null
              ? Icon(Icons.person_rounded, color: g.accent, size: 28)
              : Image.asset(
                  avatarAsset!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Icon(Icons.person_rounded, color: g.accent, size: 28),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  color: g.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: g.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onNotificationTap,
            customBorder: const CircleBorder(),
            child: Ink(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: g.surface,
                shape: BoxShape.circle,
                border: Border.all(color: g.accentTint, width: 1.5),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    color: g.accent,
                    size: 24,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: g.danger,
                          shape: BoxShape.circle,
                          border: Border.all(color: g.surface, width: 1.5),
                        ),
                      ),
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
