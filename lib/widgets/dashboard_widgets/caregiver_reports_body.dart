import 'package:flutter/material.dart';

import '../../models/linked_navigator.dart';
import '../../theme/gabay_theme.dart';
import '../shared/gabay_card.dart';
import '../shared/gabay_page_header.dart';
import '../shared/floating_bottom_nav_shell.dart';
import 'stat_card.dart';

class CaregiverReportsBody extends StatefulWidget {
  const CaregiverReportsBody({super.key});

  @override
  State<CaregiverReportsBody> createState() => _CaregiverReportsBodyState();
}

class _CaregiverReportsBodyState extends State<CaregiverReportsBody> {
  late LinkedNavigator _selectedNavigator;

  @override
  void initState() {
    super.initState();
    _selectedNavigator = LinkedNavigatorService.navigators.first;
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.gabay.accent;
    final nav = _selectedNavigator;

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
          const GabayPageHeader(
            title: 'Reports',
            subtitle: 'Track your linked navigator\'s mobility & routes',
          ),
          const SizedBox(height: 18),
          _NavigatorSelectorCard(
            navigators: LinkedNavigatorService.navigators,
            selected: nav,
            onChanged: (value) => setState(() => _selectedNavigator = value),
          ),
          const SizedBox(height: 14),
          _NavigatorSummaryCard(navigator: nav),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.today_rounded,
                  title: 'Trips Today',
                  value: '3',
                  unit: 'Trips',
                  color: accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StatCard(
                  icon: Icons.date_range_rounded,
                  title: 'This Week',
                  value: '12',
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
                  value: '8.6',
                  unit: 'Km',
                  color: accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StatCard(
                  icon: Icons.timer_rounded,
                  title: 'Avg Walk Time',
                  value: '42',
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
                Text(
                  '${nav.name.split(' ').first}\'s activity this week',
                  style: GabayTheme.labelSmall(context),
                ),
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
          const SizedBox(height: 22),
          Text('Navigation Events', style: GabayTheme.sectionTitle(context)),
          const SizedBox(height: 12),
          GabayCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _eventRow(
                  context,
                  icon: Icons.navigation_rounded,
                  title: 'Navigation started to City Hall',
                  time: 'Today • 9:15 AM',
                ),
                Divider(height: 1, color: context.gabay.border.withValues(alpha: 0.5)),
                _eventRow(
                  context,
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Destination reached: Public Market',
                  time: 'Yesterday • 8:40 AM',
                ),
                Divider(height: 1, color: context.gabay.border.withValues(alpha: 0.5)),
                _eventRow(
                  context,
                  icon: Icons.battery_alert_rounded,
                  title: 'Cane battery low (20%)',
                  time: 'Yesterday • 7:55 AM',
                ),
              ],
            ),
          ),
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
                color: accent.withValues(alpha: 0.35 + (heightFactor * 0.45)),
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

  Widget _eventRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String time,
  }) {
    final g = context.gabay;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
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
                Text(title, style: GabayTheme.bodyLarge(context).copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(time, style: GabayTheme.bodyMedium(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigatorSelectorCard extends StatelessWidget {
  const _NavigatorSelectorCard({
    required this.navigators,
    required this.selected,
    required this.onChanged,
  });

  final List<LinkedNavigator> navigators;
  final LinkedNavigator selected;
  final ValueChanged<LinkedNavigator> onChanged;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return GabayCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Viewing reports for',
            style: GabayTheme.labelSmall(context).copyWith(
              color: g.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<LinkedNavigator>(
              value: selected,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: g.textSecondary),
              style: TextStyle(
                color: g.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              items: navigators
                  .map(
                    (nav) => DropdownMenuItem(
                      value: nav,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: g.accentTint,
                            child: Text(
                              nav.name.isNotEmpty ? nav.name[0] : '?',
                              style: TextStyle(
                                color: g.accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              nav.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!nav.isOnline)
                            Text(
                              'Offline',
                              style: TextStyle(
                                fontSize: 11,
                                color: g.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigatorSummaryCard extends StatelessWidget {
  const _NavigatorSummaryCard({required this.navigator});

  final LinkedNavigator navigator;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return GabayCard(
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: g.accentTint,
                child: Text(
                  navigator.name.isNotEmpty ? navigator.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: g.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ),
              if (navigator.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: g.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: g.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(navigator.name, style: GabayTheme.bodyLarge(context)),
                const SizedBox(height: 2),
                Text(navigator.address, style: GabayTheme.bodyMedium(context)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _pill(
                      context,
                      icon: Icons.directions_walk_rounded,
                      label: navigator.status,
                    ),
                    const SizedBox(width: 8),
                    _pill(
                      context,
                      icon: Icons.battery_charging_full_rounded,
                      label: '${navigator.batteryPercent}%',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, {required IconData icon, required String label}) {
    final g = context.gabay;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: g.accentTint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: g.accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: g.accent,
            ),
          ),
        ],
      ),
    );
  }
}
