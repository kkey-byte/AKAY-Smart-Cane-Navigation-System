import 'package:flutter/material.dart';

enum NotificationCategory {
  emergency,
  location,
  connection,
  reports,
  system,
}

enum NotificationDateGroup {
  today,
  yesterday,
  older,
}

enum NotificationDestination {
  emergency,
  track,
  reports,
  profile,
  none,
}

class GabayNotification {
  const GabayNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.createdAt,
    this.isRead = false,
    required this.destination,
  });

  final String id;
  final NotificationCategory category;
  final String title;
  final String description;
  final DateTime createdAt;
  final bool isRead;
  final NotificationDestination destination;

  GabayNotification copyWith({
    bool? isRead,
  }) {
    return GabayNotification(
      id: id,
      category: category,
      title: title,
      description: description,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      destination: destination,
    );
  }

  NotificationDateGroup get dateGroup {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final created = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final difference = today.difference(created).inDays;

    if (difference == 0) return NotificationDateGroup.today;
    if (difference == 1) return NotificationDateGroup.yesterday;
    return NotificationDateGroup.older;
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hr${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  IconData get icon {
    switch (category) {
      case NotificationCategory.emergency:
        return Icons.sos_rounded;
      case NotificationCategory.location:
        return Icons.navigation_rounded;
      case NotificationCategory.connection:
        return Icons.link_rounded;
      case NotificationCategory.reports:
        return Icons.assessment_outlined;
      case NotificationCategory.system:
        return Icons.settings_outlined;
    }
  }

  String get dateGroupLabel {
    switch (dateGroup) {
      case NotificationDateGroup.today:
        return 'TODAY';
      case NotificationDateGroup.yesterday:
        return 'YESTERDAY';
      case NotificationDateGroup.older:
        return 'OLDER';
    }
  }
}
