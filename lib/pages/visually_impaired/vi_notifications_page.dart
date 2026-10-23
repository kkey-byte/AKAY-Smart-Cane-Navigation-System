import 'package:flutter/material.dart';
import '../../widgets/shared/gabay_detail_page_scaffold.dart';

class ViNotificationsPage extends StatelessWidget {
  const ViNotificationsPage({super.key});
  @override
  Widget build(BuildContext context) => const GabayDetailPageScaffold(
    title: 'Notifications',
    subtitle: 'Your account alerts',
    body: Center(
      child: Text('Notifications unavailable. No alert service is connected.'),
    ),
  );
}
