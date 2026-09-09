import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';
import '../../widgets/gabay_logo.dart';
import '../../widgets/shared/gabay_detail_page_scaffold.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return GabayDetailPageScaffold(
      title: 'About',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: g.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: g.border.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: g.shadow,
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: GabayLogo(size: 56, color: g.accent),
                ),
                const SizedBox(height: 16),
                Text(
                  'GABAY',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: g.heading,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 14,
                    color: g.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GabayContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Our Mission',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: g.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'GABAY empowers visually impaired navigators and their caregivers with accessible navigation, live safety monitoring, and meaningful connection — so every journey feels supported.',
                  style: TextStyle(
                    fontSize: 14,
                    color: g.textSecondary,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GabayContentCard(
            child: Column(
              children: [
                _AboutRow(
                  icon: Icons.navigation_rounded,
                  title: 'Smart Navigation',
                  subtitle: 'Voice-guided routes for navigators',
                ),
                Divider(height: 24, color: g.border.withValues(alpha: 0.5)),
                _AboutRow(
                  icon: Icons.location_searching_rounded,
                  title: 'Live Tracking',
                  subtitle: 'Real-time caregiver monitoring',
                ),
                Divider(height: 24, color: g.border.withValues(alpha: 0.5)),
                _AboutRow(
                  icon: Icons.sos_rounded,
                  title: 'Safety Alerts',
                  subtitle: 'SOS and emergency notifications',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GabayContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact & Support',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: g.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _ContactLine(icon: Icons.email_outlined, text: 'support@gabay.app'),
                const SizedBox(height: 8),
                _ContactLine(icon: Icons.language_rounded, text: 'www.gabay.app'),
                const SizedBox(height: 8),
                _ContactLine(icon: Icons.place_outlined, text: 'Panabo City, Davao del Norte, Philippines'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '© 2026 GABAY. All rights reserved.',
              style: TextStyle(
                fontSize: 12,
                color: g.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: g.accentTint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: g.accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: g.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: g.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Row(
      children: [
        Icon(icon, size: 18, color: g.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: g.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
