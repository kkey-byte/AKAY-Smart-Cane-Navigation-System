import '../shared/gabay_action_card_header.dart';
import 'package:flutter/material.dart';
import '../../models/pairing.dart';
import '../../theme/gabay_theme.dart';
import '../shared/gabay_card.dart';

class SmartCaneActionCard extends StatelessWidget {
  const SmartCaneActionCard({
    super.key,
    required this.onRegister,
    this.compact = false,
  });
  final VoidCallback? onRegister;
  final bool compact;
  @override
  Widget build(BuildContext context) => GabayCard(
    padding: EdgeInsets.all(compact ? 12 : 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const GabayActionCardHeader(
          icon: Icons.sensors_rounded,
          title: 'Register Smart Cane',
          description: 'Connect your smart cane to AKAY.',
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: compact
              ? FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : null,
          onPressed: onRegister,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Register Cane'),
        ),
      ],
    ),
  );
}

class NavigatorSmartCaneSection extends StatelessWidget {
  const NavigatorSmartCaneSection({
    super.key,
    required this.devices,
    required this.loading,
    required this.onManage,
    required this.onRetry,
    this.onRegister,
    this.error,
  });
  final List<RegisteredCane>? devices;
  final bool? loading;
  final String? error;
  final VoidCallback? onManage, onRetry, onRegister;
  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          (loading ?? false) || error != null
              ? 'Smart Cane'
              : 'Registered Smart Cane',
          style: GabayTheme.sectionTitle(context),
        ),
        const SizedBox(height: 12),
        if (loading ?? (devices == null && error == null))
          GabayCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                _CaneIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Loading your smart cane',
                        style: TextStyle(
                          color: g.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Checking registered devices…',
                        style: GabayTheme.labelSmall(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: 'Loading registered canes',
                  ),
                ),
              ],
            ),
          )
        else if (error != null)
          GabayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(error!, style: GabayTheme.bodyMedium(context)),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry device list'),
                ),
              ],
            ),
          )
        else if (devices?.isEmpty == true)
          GabayCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CaneIcon(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Smart Cane Registered',
                        style: GabayTheme.sectionTitle(
                          context,
                        ).copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your registered smart cane will appear here once connected.',
                        style: GabayTheme.bodyMedium(
                          context,
                        ).copyWith(fontSize: 13),
                      ),
                      if (onRegister != null) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: onRegister,
                          child: const Text('Register Cane'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          for (final device in {
            for (final device in devices ?? <RegisteredCane>[])
              device.id: device,
          }.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GabayCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CaneIcon(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.serial,
                            style: TextStyle(
                              color: g.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Device ID: ${device.id}',
                            style: GabayTheme.labelSmall(context),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _DeviceStatus(
                                label: 'Registered',
                                icon: Icons.verified_outlined,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _CaneIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: context.gabay.accentTint,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(Icons.sensors_rounded, color: context.gabay.accent, size: 24),
  );
}

class _DeviceStatus extends StatelessWidget {
  const _DeviceStatus({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: context.gabay.accentTint,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: context.gabay.accent),
        const SizedBox(width: 5),
        Flexible(child: Text(label, style: GabayTheme.labelSmall(context))),
      ],
    ),
  );
}
