import 'package:flutter/material.dart';

import '../../models/gabay_notification.dart';
import '../../services/notification_service.dart';
import '../../theme/gabay_theme.dart';
import '../../widgets/notifications/notification_card.dart';
import '../../widgets/notifications/notification_empty_state.dart';
import '../../widgets/notifications/notification_section_label.dart';

typedef NotificationNavigateCallback = void Function(
  NotificationDestination destination,
);

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    this.onNavigate,
  });

  final NotificationNavigateCallback? onNavigate;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  final _service = NotificationService.instance;
  late AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _entryController.dispose();
    super.dispose();
  }

  void _onServiceChanged() => setState(() {});

  void _handleTap(GabayNotification notification) {
    _service.markAsRead(notification.id);
    if (notification.destination == NotificationDestination.none) return;
    widget.onNavigate?.call(notification.destination);
  }

  Future<void> _confirmClearAll() async {
    final g = context.gabay;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: g.surface,
        title: Text(
          'Clear all notifications?',
          style: TextStyle(color: g.textPrimary),
        ),
        content: Text(
          'This will remove all notifications from your list.',
          style: TextStyle(color: g.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: TextStyle(color: g.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Clear all', style: TextStyle(color: g.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _service.clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _service.notifications;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: notifications.isEmpty
                  ? FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _entryController,
                        curve: Curves.easeOut,
                      ),
                      child: const NotificationEmptyState(),
                    )
                  : _buildNotificationList(notifications),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final g = context.gabay;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: g.heading),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: GabayTheme.sectionTitle(context).copyWith(
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stay updated with important activities.',
                    style: GabayTheme.bodyMedium(context).copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: g.textPrimary),
            color: g.surface,
            onSelected: (value) {
              if (value == 'read') {
                _service.markAllAsRead();
              } else if (value == 'clear') {
                _confirmClearAll();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'read',
                child: Row(
                  children: [
                    Icon(Icons.done_all_rounded, size: 20, color: g.accent),
                    const SizedBox(width: 12),
                    Text('Mark all as read', style: TextStyle(color: g.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, size: 20, color: g.danger),
                    const SizedBox(width: 12),
                    Text('Clear all', style: TextStyle(color: g.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(List<GabayNotification> notifications) {
    final groups = [
      NotificationDateGroup.today,
      NotificationDateGroup.yesterday,
      NotificationDateGroup.older,
    ];

    final widgets = <Widget>[];
    var animationIndex = 0;

    for (final group in groups) {
      final items = notifications
          .where((notification) => notification.dateGroup == group)
          .toList(growable: false);
      if (items.isEmpty) continue;

      widgets.add(NotificationSectionLabel(label: _groupLabel(group)));

      for (final item in items) {
        final currentIndex = animationIndex;
        animationIndex++;

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AnimatedNotificationItem(
              index: currentIndex,
              controller: _entryController,
              child: NotificationCard(
                notification: item,
                onTap: () => _handleTap(item),
                onDismissed: () => _service.delete(item.id),
              ),
            ),
          ),
        );
      }

      widgets.add(const SizedBox(height: 6));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: widgets,
    );
  }

  String _groupLabel(NotificationDateGroup group) {
    switch (group) {
      case NotificationDateGroup.today:
        return 'TODAY';
      case NotificationDateGroup.yesterday:
        return 'YESTERDAY';
      case NotificationDateGroup.older:
        return 'OLDER';
    }
  }
}

class _AnimatedNotificationItem extends StatelessWidget {
  const _AnimatedNotificationItem({
    required this.index,
    required this.controller,
    required this.child,
  });

  final int index;
  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.06).clamp(0.0, 0.6);
    final end = (start + 0.35).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
