import 'weekly_distance_chart.dart';
import '../shared/gabay_metric_grid.dart';
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
        value: values['Walking Duration'] ?? 'Not available',
        icon: Icons.timer_outlined,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GabayMetricGrid(
          children: [
            for (final field in fields)
              GabayCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _iconBadge(field.icon),
                    const Spacer(),
                    Tooltip(
                      message: field.value,
                      child: Text(
                        field.value == 'Unavailable' ||
                                field.value == 'Not available'
                            ? '—'
                            : field.value.replaceFirst(
                                RegExp(r'\s+recorded$'),
                                '',
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: GabayTypography.metric,
                          fontWeight: GabayTypography.semibold,
                          color: g.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      field.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: GabayTypography.supporting,
                        color: g.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        WeeklyDistanceChart(trips: trips),
        const SizedBox(height: 24),
        BreadcrumbTripRecords(
          heading: 'Recent Trips',
          controls: localOwner ? const BreadcrumbReportControls() : null,
          dataAvailable: recent != null,
          trips: recent ?? const [],
          localOwner: localOwner,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

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
