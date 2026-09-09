import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';
import '../shared/gabay_card.dart';
import '../shared/gabay_page_header.dart';
import '../shared/floating_bottom_nav_shell.dart';
import 'stat_card.dart';

class ReportsBody extends StatelessWidget {
  const ReportsBody({
    super.key,
    required this.subtitle,
    this.tripsToday = '3',
    this.tripsThisWeek = '12',
    this.totalDistance = '8.6',
    this.avgWalkTime = '42',
  });

  final String subtitle;
  final String tripsToday;
  final String tripsThisWeek;
  final String totalDistance;
  final String avgWalkTime;

  @override
  Widget build(BuildContext context) {
    final accent = context.gabay.accent;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        GabayNavMetrics.contentClearance,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GabayPageHeader(
            title: 'Reports',
            subtitle: subtitle,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.today_rounded,
                  title: 'Trips Today',
                  value: tripsToday,
                  unit: 'Trips',
                  color: accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StatCard(
                  icon: Icons.date_range_rounded,
                  title: 'This Week',
                  value: tripsThisWeek,
                  unit: 'Trips',
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.straighten_rounded,
                  title: 'Total Distance',
                  value: totalDistance,
                  unit: 'Km',
                  color: accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StatCard(
                  icon: Icons.timer_rounded,
                  title: 'Avg Walk Time',
                  value: avgWalkTime,
                  unit: 'Min',
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Walking Duration', style: GabayTheme.sectionTitle(context)),
          const SizedBox(height: 12),
          GabayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This Week', style: GabayTheme.labelSmall(context)),
                const SizedBox(height: 18),
                SizedBox(
                  height: 120,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _bar(context, 'Mon', 0.5, accent),
                      _bar(context, 'Tue', 0.7, accent),
                      _bar(context, 'Wed', 0.4, accent),
                      _bar(context, 'Thu', 0.9, accent),
                      _bar(context, 'Fri', 0.6, accent),
                      _bar(context, 'Sat', 0.3, accent),
                      _bar(context, 'Sun', 0.8, accent),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Most Visited Places', style: GabayTheme.sectionTitle(context)),
          const SizedBox(height: 12),
          _visitedTile(context, 'City Hall', '5 visits', Icons.account_balance_rounded, accent),
          _visitedTile(context, 'Public Market', '4 visits', Icons.store_rounded, accent),
          _visitedTile(context, 'Health Center', '3 visits', Icons.local_hospital_rounded, accent),
          const SizedBox(height: 22),
          Text('Recent Trips', style: GabayTheme.sectionTitle(context)),
          const SizedBox(height: 12),
          _tripCard(context, 'City Hall', 'Today • 2.1 km • 38 min', accent),
          _tripCard(context, 'Public Market', 'Yesterday • 1.4 km • 22 min', accent),
          _tripCard(context, 'Health Center', 'Mon • 3.2 km • 48 min', accent),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, String label, double heightFactor, Color accent) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              height: 90 * heightFactor,
              decoration: BoxDecoration(
                color: accent.withValues(
                  alpha: 0.35 + (heightFactor * 0.45),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GabayTheme.labelSmall(context).copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visitedTile(
    BuildContext context,
    String place,
    String visits,
    IconData icon,
    Color accent,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GabayCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.gabay.accentTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place, style: GabayTheme.bodyLarge(context)),
                  Text(visits, style: GabayTheme.bodyMedium(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripCard(
    BuildContext context,
    String destination,
    String details,
    Color accent,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GabayCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(destination, style: GabayTheme.bodyLarge(context)),
                  const SizedBox(height: 4),
                  Text(details, style: GabayTheme.bodyMedium(context)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accent),
          ],
        ),
      ),
    );
  }
}
