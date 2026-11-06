import 'package:flutter/material.dart';
import '../../widgets/shared/gabay_detail_page_scaffold.dart';
import '../../widgets/notifications/notification_empty_state.dart';

class ViNotificationsPage extends StatelessWidget {
  const ViNotificationsPage({super.key});
  @override
  Widget build(BuildContext context) => const GabayDetailPageScaffold(
    title: 'Notifications',
    body: NotificationEmptyState(),
  );
}
