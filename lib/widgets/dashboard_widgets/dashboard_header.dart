import '../../theme/gabay_typography.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

import '../../theme/gabay_theme.dart';
import '../shared/gabay_glass_surface.dart';
import '../shared/gabay_dashboard_backdrop.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    this.onNotificationTap,
    this.unreadCount = 0,
    this.greeting = 'Hello, Welcome back!',
    this.name = 'User',
    this.avatarAsset,
    this.avatarUrl,
    this.nameFontSize = 22,
    this.nameFontWeight = GabayTypography.bold,
    this.glass = false,
  });

  final VoidCallback? onNotificationTap;
  final int unreadCount;
  final String greeting;
  final String name;
  final String? avatarAsset;
  final String? avatarUrl;
  final double nameFontSize;
  final FontWeight nameFontWeight;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final onBackdrop = GabayDashboardBackdrop.active(context);
    ImageProvider? photo;
    try {
      final url = avatarUrl?.trim();
      if (url?.startsWith('data:image/') == true) {
        photo = MemoryImage(base64Decode(url!.split(',').last));
      } else if (url != null &&
          ['https', 'http'].contains(Uri.tryParse(url)?.scheme)) {
        photo = NetworkImage(url);
      } else if (avatarAsset != null) {
        photo = AssetImage(avatarAsset!);
      }
    } catch (_) {
      // Keep the placeholder if the saved image cannot be decoded.
    }

    final header = Container(
      padding: onBackdrop
          ? const EdgeInsets.symmetric(vertical: 8)
          : const EdgeInsets.all(16),
      decoration: onBackdrop || glass
          ? null
          : GabayTheme.cardDecoration(context).copyWith(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [g.accentTint, g.surface.withValues(alpha: .94)],
              ),
            ),
      child: Row(
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
            child: photo == null
                ? Icon(Icons.person_rounded, color: g.accent, size: 28)
                : Image(
                    image: photo,
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
                    color: onBackdrop
                        ? GabayDashboardBackdrop.secondaryColor(context)
                        : g.textSecondary,
                    fontSize: GabayTypography.body,
                    fontWeight: GabayTypography.medium,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: nameFontSize,
                    fontWeight: onBackdrop
                        ? GabayTypography.medium
                        : nameFontWeight,
                    color: onBackdrop
                        ? GabayDashboardBackdrop.primaryColor(context)
                        : g.textPrimary,
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
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: onBackdrop
                          ? GabayDashboardBackdrop.primaryColor(context)
                          : g.accent,
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
      ),
    );
    return glass && !onBackdrop
        ? GabayGlassSurface(radius: 24, child: header)
        : header;
  }
}
