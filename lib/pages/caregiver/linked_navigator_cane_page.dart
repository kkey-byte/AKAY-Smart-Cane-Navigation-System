import 'package:flutter/material.dart';

import '../../models/linked_navigator.dart';
import '../../theme/gabay_theme.dart';
import '../../widgets/shared/gabay_detail_page_scaffold.dart';

class LinkedNavigatorCanePage extends StatelessWidget {
  const LinkedNavigatorCanePage({super.key});

  @override
  Widget build(BuildContext context) {
    final navigators = LinkedNavigatorService.navigators;
    final activeCount = navigators.where((n) => n.isOnline).length;

    return GabayDetailPageScaffold(
      title: 'Linked Navigator Cane',
      subtitle: 'Manage smart canes paired to your linked navigators.',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          GabayContentCard(
            child: Row(
              children: [
                _SummaryTile(
                  icon: Icons.devices_other_rounded,
                  label: 'Paired Canes',
                  value: '${navigators.length}',
                  color: context.gabay.accent,
                ),
                Container(
                  width: 1,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: context.gabay.border.withValues(alpha: 0.6),
                ),
                _SummaryTile(
                  icon: Icons.wifi_tethering_rounded,
                  label: 'Active Now',
                  value: '$activeCount',
                  color: context.gabay.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const GabaySectionLabel(label: 'Linked Devices'),
          ...navigators.map(
            (navigator) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _NavigatorCaneCard(navigator: navigator),
            ),
          ),
          const SizedBox(height: 8),
          GabayContentCard(
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: context.gabay.accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pair a new smart cane by scanning the QR code on the device or approving a pairing request from a navigator.',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.gabay.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pair new cane — ready for device pairing flow'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: Icon(Icons.qr_code_scanner_rounded, color: context.gabay.accent),
              label: Text(
                'Pair New Cane',
                style: TextStyle(
                  color: context.gabay.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: context.gabay.accent.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Expanded(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: g.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: g.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigatorCaneCard extends StatelessWidget {
  const _NavigatorCaneCard({required this.navigator});

  final LinkedNavigator navigator;

  String get _caneId => 'GABAY-CANE-${navigator.id.split('_').last.toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final statusColor = navigator.isOnline ? g.success : g.textSecondary;

    return GabayContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: g.accentTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.blind_rounded, color: g.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      navigator.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: g.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _caneId,
                      style: TextStyle(
                        fontSize: 12,
                        color: g.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  navigator.isOnline ? 'Connected' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: g.border.withValues(alpha: 0.55)),
          const SizedBox(height: 12),
          Row(
            children: [
              _DetailChip(
                icon: Icons.bolt_rounded,
                label: 'Battery',
                value: '${navigator.batteryPercent}%',
              ),
              const SizedBox(width: 10),
              _DetailChip(
                icon: Icons.sync_rounded,
                label: 'Status',
                value: navigator.status,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: g.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  navigator.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: g.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: g.chipBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: g.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: g.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: g.textSecondary),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: g.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
