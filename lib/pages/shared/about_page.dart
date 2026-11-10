import 'package:flutter/material.dart';
import '../../theme/gabay_theme.dart';
import '../../theme/gabay_typography.dart';
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
          GabayContentCard(
            child: Column(
              children: [
                const GabayLogo(size: 120),
                Text(
                  'AKAY',
                  style: TextStyle(
                    color: g.heading,
                    fontSize: GabayTypography.hero,
                    fontWeight: GabayTypography.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Independence Starts Here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: g.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: g.accentTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(color: g.accent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Our Mission', style: GabayTheme.sectionTitle(context)),
          const SizedBox(height: 8),
          Text(
            'AKAY brings navigation and caregiver connection together to support visually impaired people in their everyday journeys. The project combines a smart-cane navigation concept with a mobile companion for navigators and their caregivers.',
            style: GabayTheme.bodyMedium(context).copyWith(height: 1.6),
          ),
          const SizedBox(height: 20),
          _section(context, 'Made for supported journeys', [
            (
              icon: Icons.route_outlined,
              title: 'Plan and review journeys',
              body:
                  'Find destinations, plan walking routes, and revisit recorded trips in one place.',
            ),
            (
              icon: Icons.location_on_outlined,
              title: 'Stay connected',
              body:
                  'Caregivers can follow a navigator’s latest shared location when location updates and sharing access are available.',
            ),
            (
              icon: Icons.favorite_border_rounded,
              title: 'Keep useful details together',
              body:
                  'Organize profile, health, and emergency contact information for easier reference.',
            ),
          ]),
          const SizedBox(height: 14),
          _section(context, 'Two roles. One connection.', [
            (
              icon: Icons.directions_walk_rounded,
              title: 'For Navigators',
              body:
                  'Manage your profile, choose a destination, review your trips, and decide which caregivers to connect with.',
            ),
            (
              icon: Icons.people_outline_rounded,
              title: 'For Caregivers',
              body:
                  'Switch between linked navigators and review the location, trips, and information they are authorized to share.',
            ),
          ]),
          const SizedBox(height: 14),
          GabayContentCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined, color: g.accent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sharing stays in your control',
                        style: GabayTheme.sectionTitle(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Connect through an AKAY pairing code or QR. Navigators authorize caregiver access and can disconnect a caregiver when needed.',
                        style: GabayTheme.bodyMedium(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'AKAY • Smart Cane Navigation & Caregiver Monitoring',
            textAlign: TextAlign.center,
            style: GabayTheme.labelSmall(context),
          ),
          const SizedBox(height: 8),
          Text(
            '© 2026 AKAY. All rights reserved.',
            textAlign: TextAlign.center,
            style: GabayTheme.labelSmall(context),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    List<({IconData icon, String title, String body})> items,
  ) {
    final g = context.gabay;
    return GabayContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GabayTheme.sectionTitle(context)),
          const SizedBox(height: 16),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(
                  height: 1,
                  color: g.border.withValues(alpha: .6),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: g.accentTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(items[i].icon, color: g.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].title,
                        style: TextStyle(
                          color: g.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        items[i].body,
                        style: GabayTheme.bodyMedium(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
