import 'package:flutter/foundation.dart';

import '../models/gabay_notification.dart';

class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final List<GabayNotification> _notifications = _seedNotifications();

  List<GabayNotification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  bool get isEmpty => _notifications.isEmpty;

  List<GabayNotification> grouped(NotificationDateGroup group) {
    return _notifications.where((n) => n.dateGroup == group).toList();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1 || _notifications[index].isRead) return;
    _notifications[index] = _notifications[index].copyWith(isRead: true);
    notifyListeners();
  }

  void markAllAsRead() {
    var changed = false;
    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void clearAll() {
    if (_notifications.isEmpty) return;
    _notifications.clear();
    notifyListeners();
  }

  void delete(String id) {
    final lengthBefore = _notifications.length;
    _notifications.removeWhere((n) => n.id == id);
    if (_notifications.length != lengthBefore) notifyListeners();
  }

  static List<GabayNotification> _seedNotifications() {
    final now = DateTime.now();

    return [
      GabayNotification(
        id: 'n1',
        category: NotificationCategory.emergency,
        title: 'Emergency SOS Activated',
        description: 'John requested immediate assistance.',
        createdAt: now.subtract(const Duration(minutes: 2)),
        destination: NotificationDestination.emergency,
      ),
      GabayNotification(
        id: 'n2',
        category: NotificationCategory.location,
        title: 'Navigation Started',
        description: 'Maria began navigating to City Hall.',
        createdAt: now.subtract(const Duration(minutes: 45)),
        destination: NotificationDestination.track,
      ),
      GabayNotification(
        id: 'n3',
        category: NotificationCategory.connection,
        title: 'Pairing Successful',
        description: 'Juan Dela Cruz is now linked to your account.',
        createdAt: now.subtract(const Duration(hours: 3)),
        isRead: true,
        destination: NotificationDestination.profile,
      ),
      GabayNotification(
        id: 'n4',
        category: NotificationCategory.emergency,
        title: 'Fall Detected',
        description: 'Possible fall detected for Pedro Reyes.',
        createdAt: now.subtract(const Duration(hours: 5)),
        isRead: true,
        destination: NotificationDestination.emergency,
      ),
      GabayNotification(
        id: 'n5',
        category: NotificationCategory.location,
        title: 'Destination Reached',
        description: 'Glaisa arrived at Panabo City Hall.',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        destination: NotificationDestination.track,
      ),
      GabayNotification(
        id: 'n6',
        category: NotificationCategory.location,
        title: 'Live Location Shared',
        description: 'Maria shared her live location with you.',
        createdAt: now.subtract(const Duration(days: 1, hours: 8)),
        isRead: true,
        destination: NotificationDestination.track,
      ),
      GabayNotification(
        id: 'n7',
        category: NotificationCategory.connection,
        title: 'New Pairing Request',
        description: 'Ana Santos sent a navigator pairing request.',
        createdAt: now.subtract(const Duration(days: 1, hours: 14)),
        destination: NotificationDestination.profile,
      ),
      GabayNotification(
        id: 'n8',
        category: NotificationCategory.reports,
        title: 'Weekly Travel Report Ready',
        description: 'Your navigator activity summary is available.',
        createdAt: now.subtract(const Duration(days: 3)),
        isRead: true,
        destination: NotificationDestination.reports,
      ),
      GabayNotification(
        id: 'n9',
        category: NotificationCategory.reports,
        title: 'Trip Completed',
        description: 'Juan completed a 2.4 km route to Gaisano Mall.',
        createdAt: now.subtract(const Duration(days: 4)),
        isRead: true,
        destination: NotificationDestination.reports,
      ),
      GabayNotification(
        id: 'n10',
        category: NotificationCategory.emergency,
        title: 'Safe Zone Exited',
        description: 'Pedro left the designated home safe zone.',
        createdAt: now.subtract(const Duration(days: 5)),
        isRead: true,
        destination: NotificationDestination.emergency,
      ),
      GabayNotification(
        id: 'n11',
        category: NotificationCategory.connection,
        title: 'Connection Removed',
        description: 'Link with Carlos Mendoza was removed.',
        createdAt: now.subtract(const Duration(days: 6)),
        isRead: true,
        destination: NotificationDestination.profile,
      ),
      GabayNotification(
        id: 'n12',
        category: NotificationCategory.system,
        title: 'GPS Disabled',
        description: 'Navigator GPS was turned off on Maria\'s device.',
        createdAt: now.subtract(const Duration(days: 7)),
        isRead: true,
        destination: NotificationDestination.none,
      ),
      GabayNotification(
        id: 'n13',
        category: NotificationCategory.system,
        title: 'Internet Connection Lost',
        description: 'Live tracking paused due to connectivity.',
        createdAt: now.subtract(const Duration(days: 8)),
        isRead: true,
        destination: NotificationDestination.none,
      ),
      GabayNotification(
        id: 'n14',
        category: NotificationCategory.system,
        title: 'App Update Available',
        description: 'GABAY v1.1.0 is ready to install.',
        createdAt: now.subtract(const Duration(days: 10)),
        isRead: true,
        destination: NotificationDestination.none,
      ),
    ];
  }
}
