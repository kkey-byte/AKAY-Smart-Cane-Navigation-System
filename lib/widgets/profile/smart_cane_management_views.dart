import 'package:flutter/material.dart';
import '../../models/pairing.dart';
import '../../theme/gabay_theme.dart';
import '../shared/gabay_card.dart';
import '../shared/gabay_action_card_header.dart';

class SmartCaneInfoCard extends StatelessWidget {
  const SmartCaneInfoCard({super.key, this.registration = false});
  final bool? registration;
  @override
  Widget build(BuildContext context) => GabayCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GabayActionCardHeader(
          icon: registration == true
              ? Icons.add_rounded
              : Icons.settings_outlined,
          title: registration == true
              ? 'Cane registration'
              : 'Device management',
          description: registration == true
              ? 'Use your server-issued code to confirm a cane authorized for your account.'
              : 'View your canes and manage their assignments and ownership.',
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
            : 'Assigned to you',
      ),
      const SizedBox(height: 10),
      Divider(height: 1, color: context.gabay.border),
      const SizedBox(height: 8),
      Text('Device ID', style: GabayTheme.labelSmall(context)),
      const SizedBox(height: 5),
      SelectableText(
        device.id,
        style: GabayTheme.bodyMedium(
          context,
        ).copyWith(fontSize: 13, height: 1.5),
      ),
      const SizedBox(height: 8),
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
