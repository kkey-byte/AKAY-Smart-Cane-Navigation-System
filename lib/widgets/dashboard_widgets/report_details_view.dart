import '../../theme/gabay_typography.dart';
import '../shared/gabay_accent_icon.dart';
import 'package:flutter/material.dart';
import '../../models/breadcrumb_trip.dart';
import '../../theme/gabay_theme.dart';
import '../shared/gabay_card.dart';
import '../track/breadcrumb_trip_records.dart';
import '../track/breadcrumb_report_controls.dart';

/// Presentation only: values are supplied by the existing report calculation.
class ReportDetailsView extends StatelessWidget {
  const ReportDetailsView({
    super.key,
    required this.values,
    required this.trips,
    this.recentTrips,
    this.localOwner = false,
  });
  final Map<String, String> values;
  final List<BreadcrumbTrip>? trips;
  final List<BreadcrumbTrip>? recentTrips;
  final bool localOwner;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).extension<GabayThemeExtension>() == null) {
      return Theme(
        data: Theme.of(context).copyWith(
          extensions: [
            ...Theme.of(context).extensions.values,
            _reportColors(context),
          ],
        ),
        child: ReportDetailsView(
          values: values,
          trips: trips,
          recentTrips: recentTrips,
          localOwner: localOwner,
        ),
      );
    }
    final g = _reportColors(context);
    final recent = recentTrips ?? trips;
    final fields = [
      (
        label: 'Trips Today',
        value: values['Trips Today']!,
        icon: Icons.calendar_today_outlined,
      ),
      (
        label: 'This Week',
        value: values['This Week']!,
        icon: Icons.calendar_month_outlined,
      ),
      (
        label: 'Total Distance',
        value: values['Total Distance']!,
        icon: Icons.location_on_outlined,
      ),
      (
        label: 'Walking Duration',
        value: 'Not available',
        icon: Icons.timer_outlined,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final two =
                constraints.maxWidth >= 300 &&
                MediaQuery.textScalerOf(context).scale(16) <= 22;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final field in fields)
                  SizedBox(
                    width: two
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth,
                    child: GabayCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _iconBadge(field.icon),
                          const SizedBox(height: 8),
                          Text(
                            field.value == 'Unavailable' ||
                                    field.value == 'Not available'
                                ? '—'
                                : field.value,
                            style: TextStyle(
                              fontSize: GabayTypography.subheading,
                              fontWeight: GabayTypography.regular,
                              color: g.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            field.label,
                            style: TextStyle(
                              fontSize: GabayTypography.caption,
                              color: g.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        GabayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This week',
                style: TextStyle(
                  fontSize: GabayTypography.cardTitle,
                  fontWeight: GabayTypography.regular,
                  color: g.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              // Neutral rails are an empty chart state, never fabricated activity.
              ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final day in [
                      'MON',
                      'TUE',
                      'WED',
                      'THU',
                      'FRI',
                      'SAT',
                      'SUN',
                    ])
                      Flexible(
                        child: Column(
                          children: [
                            Container(
                              width: 8,
                              height: 115,
                              decoration: BoxDecoration(
                                color: g.border,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              day,
                              style: TextStyle(
                                fontSize: GabayTypography.chartLabel,
                                color: g.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No daily activity data to display.',
                style: TextStyle(
                  color: g.textSecondary,
                  fontSize: GabayTypography.caption,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _heading(context, 'Recent Trips'),
        if (localOwner) ...[
          const SizedBox(height: 12),
          const BreadcrumbReportControls(),
        ],
        const SizedBox(height: 12),
        if (recent != null && recent.isEmpty)
          GabayCard(
            child: Text(
              'No recorded tracks yet.',
              style: TextStyle(
                color: g.textSecondary,
                fontSize: GabayTypography.supporting,
                fontWeight: GabayTypography.regular,
              ),
            ),
          ),
        BreadcrumbTripRecords(
          trips: recent ?? const [],
          localOwner: localOwner,
        ),
        const SizedBox(height: 24),
        _heading(context, 'Navigation Events'),
        const SizedBox(height: 12),
        GabayCard(
          child: Text(
            'No navigation event data to display.',
            style: TextStyle(
              color: g.textSecondary,
              fontSize: GabayTypography.supporting,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _heading(context, 'Most Visited Places'),
        const SizedBox(height: 12),
        GabayCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _iconBadge(Icons.apartment),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No visit data to display.',
                  style: TextStyle(
                    color: g.textSecondary,
                    fontSize: GabayTypography.supporting,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _heading(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      color: _reportColors(context).textPrimary,
      fontSize: GabayTypography.sectionTitle,
      fontWeight: GabayTypography.semibold,
    ),
  );
  Widget _iconBadge(IconData icon) {
    final accent = GabayAccentIcon.accent(icon);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(accent, Colors.white, .30)!, accent],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: .18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

GabayThemeExtension _reportColors(BuildContext context) =>
    Theme.of(context).extension<GabayThemeExtension>() ??
    (Theme.of(context).brightness == Brightness.dark
        ? GabayThemeExtension.dark
        : GabayThemeExtension.light);
