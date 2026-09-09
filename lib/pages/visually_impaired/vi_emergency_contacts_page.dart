import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';
import '../../widgets/shared/gabay_detail_page_scaffold.dart';

class ViEmergencyContactsPage extends StatelessWidget {
  const ViEmergencyContactsPage({super.key});

  static const _contacts = [
    ('Maria Batulanon', 'Mother', '+63 917 000 1111'),
    ('Panabo City Rescue', 'Emergency Hotline', '911'),
    ('Mariel Regine Glaisa', 'Primary Caregiver', '+63 998 877 6655'),
  ];

  @override
  Widget build(BuildContext context) {
    return GabayDetailPageScaffold(
      title: 'Emergency Contacts',
      subtitle: 'Quick access during SOS or urgent situations.',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          GabayContentCard(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.gabay.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.sos_rounded, color: context.gabay.danger, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'These contacts are notified automatically when you trigger Emergency SOS from the home screen.',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.gabay.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const GabaySectionLabel(label: 'Contacts'),
          GabayContentCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _contacts.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: context.gabay.border.withValues(alpha: 0.5),
                    ),
                  _ContactRow(
                    name: _contacts[i].$1,
                    relationship: _contacts[i].$2,
                    phone: _contacts[i].$3,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.name,
    required this.relationship,
    required this.phone,
  });

  final String name;
  final String relationship;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Calling $name...'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: g.accentTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person_outline_rounded, color: g.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: g.textPrimary,
                      ),
                    ),
                    Text(relationship, style: TextStyle(fontSize: 12, color: g.textSecondary)),
                  ],
                ),
              ),
              Text(
                phone,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: g.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
