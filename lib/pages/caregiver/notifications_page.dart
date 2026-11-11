import '../../widgets/shared/gabay_modal_motion.dart';
import '../../theme/gabay_typography.dart';
import '../../widgets/shared/gabay_page_header.dart';
import '../../widgets/shared/gabay_accent_icon.dart';
import '../../widgets/shared/gabay_page_background.dart';
import 'package:flutter/material.dart';

import '../../models/gabay_notification.dart';
import '../../services/notification_service.dart';
import '../../services/emergency_push_service.dart';
import '../../theme/gabay_theme.dart';
import '../../widgets/shared/gabay_selection_dialog.dart';
import '../../widgets/notifications/notification_card.dart';
import '../../widgets/notifications/notification_empty_state.dart';
import '../../widgets/notifications/notification_section_label.dart';

typedef NotificationNavigateCallback =
    void Function(NotificationDestination destination);

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.onNavigate, this.service});

  final NotificationNavigateCallback? onNavigate;
  final NotificationService? service;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  late final NotificationService _service;
  late AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? NotificationService.instance;
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
    if (notification.incident != null) {
      _showIncident(notification.id);
      return;
    }
    if (notification.destination == NotificationDestination.none) return;
    widget.onNavigate?.call(notification.destination);
  }

  Future<void> _showIncident(String id) async {
    var busy = false;
    String? error;
    await showDialog<void>(
      animationStyle: gabayModalAnimation(context),
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => ListenableBuilder(
          listenable: _service,
          builder: (context, _) {
            final matches = _service.notifications.where(
              (n) => n.id == id && n.incident != null,
            );
            final incident = matches.isEmpty ? null : matches.first.incident;
            Future<void> respond(String action) async {
              setDialogState(() {
                busy = true;
                error = null;
              });
              try {
                await _service.respond(id, action);
              } catch (_) {
                if (context.mounted) {
                  setDialogState(
                    () => error =
                        'Response not confirmed. Check your connection or access, then retry.',
                  );
                }
              } finally {
                if (context.mounted) setDialogState(() => busy = false);
              }
            }

            return AlertDialog(
              title: Text(incident?.title ?? 'Alert unavailable'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (incident == null)
                      const Text(
                        'Unable to load this alert. Check your connection and navigator sharing access.',
                      )
                    else ...[
                      Text('Status: ${incident.status}'),
                      const SizedBox(height: 12),
                      Text(
                        incident.kind == 'sos'
                            ? 'The navigator requested assistance using the cane SOS button.'
                            : 'The cane detected unusual movement. A fall or accident has not been confirmed. Please check on this navigator.',
                      ),
                      const SizedBox(height: 12),
                      Text('Detected: ${incident.detectedAt.toLocal()}'),
                      Text('Received: ${incident.createdAt.toLocal()}'),
                      const SizedBox(height: 12),
                      Text(
                        incident.latitude == null
                            ? 'No location was attached to this event.'
                            : 'Event location: ${incident.latitude}, ${incident.longitude}\nCaptured: ${incident.detectedAt.toLocal()} (not necessarily the current location).',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Resolving this alert records your response in AKAY. It does not remotely silence the cane.',
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, semanticsLabel: error),
                    ],
                    if (busy)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
                if (incident?.unresolved == true) ...[
                  if (incident!.acknowledgedAt == null)
                    TextButton(
                      onPressed: busy ? null : () => respond('acknowledge'),
                      child: const Text('Acknowledge'),
                    ),
                  TextButton(
                    onPressed: busy ? null : () => respond('false_alarm'),
                    child: const Text('False alarm'),
                  ),
                  FilledButton(
                    onPressed: busy ? null : () => respond('resolve'),
                    child: const Text('Resolve alert'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    final g = context.gabay;
    final confirmed = await showDialog<bool>(
      animationStyle: gabayModalAnimation(context),
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: g.surface,
        title: Text(
          'Clear all notifications?',
          style: TextStyle(color: g.textPrimary),
        ),
        content: Text(
          'This removes resolved notifications. Unresolved cane alerts stay visible until you respond.',
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
      body: GabayPageBackground(
        child: SafeArea(
          child: GabayScrollingPage(
            header: _buildHeader(context),
            body: _service.errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _service.errorMessage!,
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: () async {
                              try {
                                await _service.refresh();
                              } catch (_) {}
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : notifications.isEmpty
                ? FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _entryController,
                      curve: Curves.easeOut,
                    ),
                    child: const NotificationEmptyState(),
                  )
                : _buildNotificationList(notifications),
          ),
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
            icon: GabayAccentIcon(
              Icons.arrow_back_ios_new_rounded,
              color: g.heading,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Notifications',
                    style: GabayTheme.sectionTitle(context).copyWith(
                      fontSize: GabayTypography.pageTitle,
                      fontWeight: GabayTypography.semibold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Notification actions',
            icon: GabayAccentIcon(
              Icons.more_vert_rounded,
              color: g.textPrimary,
            ),
            onPressed: () async {
              final value = await showGabaySelectionDialog<String>(
                context,
                title: 'Notification actions',
                options: [
                  const GabaySelectionOption(
                    value: 'push',
                    child: Text('Enable push notifications'),
                  ),
                  GabaySelectionOption(
                    value: 'read',
                    child: Row(
                      children: [
                        GabayAccentIcon(
                          Icons.done_all_rounded,
                          size: 20,
                          color: g.accent,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Mark all as read')),
                      ],
                    ),
                  ),
                  GabaySelectionOption(
                    value: 'clear',
                    child: Row(
                      children: [
                        GabayAccentIcon(
                          Icons.delete_sweep_outlined,
                          size: 20,
                          color: g.danger,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Clear all')),
                      ],
                    ),
                  ),
                ],
              );
              if (!mounted) return;
              if (value == 'push') {
                try {
                  await EmergencyPushService.instance.enable();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Push notifications enabled on this device.',
                        ),
                      ),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Push registration was not confirmed. Check notification permission and Firebase configuration.',
                        ),
                      ),
                    );
                  }
                }
              } else if (value == 'read') {
                _service.markAllAsRead();
              } else if (value == 'clear') {
                _confirmClearAll();
              }
            },
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
