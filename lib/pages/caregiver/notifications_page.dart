import '../../widgets/shared/gabay_top_message.dart';
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
                if (action == 'dismiss' && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
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
              scrollable: true,
              backgroundColor: context.gabay.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFFFECACA)),
              ),
              titlePadding: EdgeInsets.zero,
              contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              title: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          incident?.kind == 'sos'
                              ? Icons.sos_rounded
                              : Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            incident?.kind == 'sos'
                                ? 'SOS EMERGENCY'
                                : 'CANE ALERT',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      incident?.title ?? 'Alert unavailable',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF991B1B)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Status: ${incident.status}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        incident.kind == 'sos'
                            ? 'The navigator requested assistance using the cane SOS button.'
                            : 'The cane detected unusual movement. A fall or accident has not been confirmed. Please check on this navigator.',
                      ),
                      const SizedBox(height: 12),
                      _EmergencyDetail(
                        icon: Icons.schedule_rounded,
                        label: incident.observedFromDatabase
                            ? 'Database observed'
                            : 'Detected',
                        value: _alertTime(context, incident.detectedAt),
                      ),
                      const SizedBox(height: 12),
                      _EmergencyDetail(
                        icon: Icons.notifications_active_outlined,
                        label: 'Received',
                        value: _alertTime(context, incident.createdAt),
                      ),
                      const SizedBox(height: 12),
                      _EmergencyDetail(
                        icon: Icons.location_on_outlined,
                        label: 'Event location',
                        value: incident.latitude == null
                            ? 'No location was attached to this event.'
                            : '${incident.latitude}, ${incident.longitude}\nAttached to this event; not necessarily the current location.',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Resolving this alert records your response in AKAY. It does not remotely silence the cane.',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        semanticsLabel: error,
                        style: TextStyle(color: context.gabay.danger),
                      ),
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
                if (incident != null)
                  TextButton(
                    onPressed: busy ? null : () => respond('dismiss'),
                    child: const Text('Delete notification'),
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
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                    ),
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

  String _alertTime(BuildContext context, DateTime date) {
    final local = date.toLocal();
    final labels = MaterialLocalizations.of(context);
    return '${labels.formatMediumDate(local)} · ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
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
          'This deletes notifications from your account. It does not resolve an incident or silence the cane.',
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
            body: _service.errorMessage != null && notifications.isEmpty
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
                    showGabayTopMessage(
                      context,
                      const SnackBar(
                        content: Text(
                          'Push notifications enabled on this device.',
                        ),
                      ),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    showGabayTopMessage(
                      context,
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

    final widgets = <Widget>[
      if (_service.errorMessage != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Showing saved alerts. ${_service.errorMessage}'),
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
    ];
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

class _EmergencyDetail extends StatelessWidget {
  const _EmergencyDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: context.gabay.danger),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: context.gabay.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: context.gabay.textPrimary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
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
