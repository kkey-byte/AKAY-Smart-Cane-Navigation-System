import 'package:flutter/material.dart';

import '../../models/navigator_health_profile.dart';
import '../../theme/gabay_theme.dart';

class InformationHealthStatusPage extends StatelessWidget {
  const InformationHealthStatusPage({
    super.key,
    required this.profile,
  });

  final NavigatorHealthProfile profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _PageHeader(onBack: () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileSummaryCard(profile: profile),
                    const SizedBox(height: 22),
                    Text(
                      'Health Overview',
                      style: GabayTheme.sectionTitle(context).copyWith(
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _HealthOverviewRow(profile: profile),
                    const SizedBox(height: 16),
                    _MedicalConditionsCard(conditions: profile.medicalConditions),
                    const SizedBox(height: 14),
                    _AllergiesCard(profile: profile),
                    const SizedBox(height: 22),
                    Text(
                      'Emergency Contact',
                      style: GabayTheme.sectionTitle(context).copyWith(
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _EmergencyContactsCard(contacts: profile.emergencyContacts),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: g.heading, size: 20),
            ),
          ),
          Text(
            'Information & Health Status',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: g.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.profile});

  final NavigatorHealthProfile profile;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(g),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: g.border, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              profile.avatarAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(
                color: g.accentTint,
                child: Icon(Icons.person_rounded, color: g.accent, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: g.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Navigator',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: g.accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.ageGenderLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: g.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: g.textSecondary,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _HealthOverviewRow extends StatelessWidget {
  const _HealthOverviewRow({required this.profile});

  final NavigatorHealthProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HealthStatCard(
            icon: Icons.water_drop_outlined,
            label: 'Blood Type',
            value: profile.bloodType,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HealthStatCard(
            icon: Icons.straighten_rounded,
            label: 'Height',
            value: profile.height,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HealthStatCard(
            icon: Icons.monitor_weight_outlined,
            label: 'Weight',
            value: profile.weight,
          ),
        ),
      ],
    );
  }
}

class _HealthStatCard extends StatelessWidget {
  const _HealthStatCard({
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: _cardDecoration(g),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: g.accentTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: g.accent),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: g.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: g.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicalConditionsCard extends StatelessWidget {
  const _MedicalConditionsCard({required this.conditions});

  final List<String> conditions;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(g),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitleRow(
            icon: Icons.warning_amber_rounded,
            title: 'Medical Conditions',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: conditions
                .map(
                  (condition) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: g.accentTint,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: g.accent.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      condition,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: g.accent,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AllergiesCard extends StatelessWidget {
  const _AllergiesCard({required this.profile});

  final NavigatorHealthProfile profile;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(g),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitleRow(
            icon: Icons.block_rounded,
            title: 'Allergies',
          ),
          const SizedBox(height: 12),
          _AllergyRow(label: 'Drug Allergies', value: profile.drugAllergies),
          Divider(height: 1, color: g.border.withValues(alpha: 0.6)),
          _AllergyRow(label: 'Food Allergies', value: profile.foodAllergies),
          Divider(height: 1, color: g.border.withValues(alpha: 0.6)),
          _AllergyRow(label: 'Other', value: profile.otherAllergies),
        ],
      ),
    );
  }
}

class _AllergyRow extends StatelessWidget {
  const _AllergyRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: g.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: g.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyContactsCard extends StatelessWidget {
  const _EmergencyContactsCard({required this.contacts});

  final List<EmergencyContactEntry> contacts;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Container(
      width: double.infinity,
      decoration: _cardDecoration(g),
      child: Column(
        children: [
          for (var i = 0; i < contacts.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: g.border.withValues(alpha: 0.6),
              ),
            _EmergencyContactRow(contact: contacts[i]),
          ],
        ],
      ),
    );
  }
}

class _EmergencyContactRow extends StatelessWidget {
  const _EmergencyContactRow({required this.contact});

  final EmergencyContactEntry contact;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: g.accentTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person_outline_rounded, color: g.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: g.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.relationship,
                  style: TextStyle(
                    fontSize: 12,
                    color: g.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            contact.phone,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: g.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTitleRow extends StatelessWidget {
  const _CardTitleRow({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: g.accentTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: g.accent),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: g.textPrimary,
          ),
        ),
      ],
    );
  }
}

BoxDecoration _cardDecoration(GabayThemeExtension g) {
  return BoxDecoration(
    color: g.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: g.border.withValues(alpha: 0.45)),
    boxShadow: [
      BoxShadow(
        color: g.shadow,
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
