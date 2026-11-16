import 'package:flutter/material.dart';
import '../../models/pairing.dart';
import '../../theme/gabay_theme.dart';
import '../shared/gabay_card.dart';
import '../shared/gabay_action_card_header.dart';

class SmartCaneInfoCard extends StatelessWidget {
  const SmartCaneInfoCard({super.key});
  @override
  Widget build(BuildContext context) => GabayCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GabayActionCardHeader(
          icon: Icons.sensors_rounded,
          title: 'Smart Canes',
          description: 'Your registered navigation devices.',
        ),
        const SizedBox(height: 14),
        Text(
          'The navigator who verifies physical possession is the registered custodian. Caregivers cannot claim or reassign canes. Multiple canes are supported.',
          style: GabayTheme.bodyMedium(
            context,
          ).copyWith(fontSize: 13, height: 1.5),
        ),
      ],
    ),
  );
}

class SmartCaneDeviceHeader extends StatelessWidget {
  const SmartCaneDeviceHeader({super.key, required this.device});
  final RegisteredCane device;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GabayActionCardHeader(
        icon: Icons.sensors_rounded,
        title: device.serial,
        description: device.assignmentId == null
            ? 'Not assigned'
            : 'Assigned to your navigator account',
      ),
      const SizedBox(height: 16),
      Divider(height: 1, color: context.gabay.border),
      const SizedBox(height: 12),
      Text('Device ID', style: GabayTheme.labelSmall(context)),
      const SizedBox(height: 5),
      SelectableText(
        device.id,
        style: GabayTheme.bodyMedium(
          context,
        ).copyWith(fontSize: 13, height: 1.5),
      ),
      const SizedBox(height: 12),
    ],
  );
}

class SmartCaneEmptyState extends StatelessWidget {
  const SmartCaneEmptyState({super.key});
  @override
  Widget build(BuildContext context) => const GabayCard(
    padding: EdgeInsets.all(18),
    child: GabayActionCardHeader(
      icon: Icons.sensors_off_rounded,
      title: 'No registered canes.',
      description: 'Your registered smart canes will appear here.',
    ),
  );
}
