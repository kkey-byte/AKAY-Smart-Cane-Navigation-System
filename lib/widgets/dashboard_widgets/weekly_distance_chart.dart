import 'package:flutter/material.dart';
import '../../models/breadcrumb_trip.dart';
import '../../theme/gabay_theme.dart';
import '../shared/gabay_card.dart';

/// Sums the existing saved trip distances; does not infer steps or walking time.
/// Trips spanning midnight are attributed to their local start date because
/// summary records do not provide per-day distance breakdowns.
List<double> recordedDistancesThisWeek(
  List<BreadcrumbTrip> trips,
  DateTime now,
) {
  final localNow = now.toLocal();
  final monday = DateTime(
    localNow.year,
    localNow.month,
    localNow.day - localNow.weekday + 1,
  );
  final sundayEnd = DateTime(monday.year, monday.month, monday.day + 7);
  final totals = List<double>.filled(7, 0);
  final seen = <(String, String)>{};
  for (final trip in trips) {
    if (!seen.add((trip.ownerId, trip.id))) continue;
    final start = trip.startedAt.toLocal();
    if (start.isBefore(monday) ||
        !start.isBefore(sundayEnd) ||
        start.isAfter(localNow)) {
      continue;
    }
    final meters = trip.distanceMeters;
    if (meters.isFinite && meters >= 0) totals[start.weekday - 1] += meters;
  }
  return totals;
}

class WeeklyDistanceChart extends StatelessWidget {
  const WeeklyDistanceChart({super.key, required this.trips, this.now});

  /// Null is unavailable/loading, while an empty list is known empty history.
  final List<BreadcrumbTrip>? trips;
  final DateTime? now;

  String _distance(double meters) => meters < 1000
      ? '${meters.toStringAsFixed(0)} m'
      : '${(meters / 1000).toStringAsFixed(2)} km';

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final totals = recordedDistancesThisWeek(
      trips ?? const [],
      now ?? DateTime.now(),
    );
    final maximum = totals.reduce((a, b) => a > b ? a : b);
    final km = maximum >= 1000;
    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return GabayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('This week', style: GabayTheme.sectionTitle(context)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
              final minimum = 7 * 42.0 * scale;
              final width = constraints.maxWidth > minimum
                  ? constraints.maxWidth
                  : minimum;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Semantics(
                            label: trips == null
                                ? '${days[i]}: saved distance unavailable'
                                : '${days[i]}: ${_distance(totals[i])} recorded',
                            excludeSemantics: true,
                            child: Tooltip(
                              message:
                                  '${days[i]}: ${trips == null ? 'Unavailable' : _distance(totals[i])}',
                              child: Column(
                                children: [
                                  Text(
                                    trips == null
                                        ? '—'
                                        : km
                                        ? (totals[i] / 1000).toStringAsFixed(2)
                                        : totals[i].toStringAsFixed(0),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GabayTheme.labelSmall(context),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 116,
                                    width: 12,
                                    child: Stack(
                                      alignment: Alignment.bottomCenter,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: g.border.withValues(
                                              alpha: .6,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        if (maximum > 0 && totals[i] > 0)
                                          Container(
                                            key: ValueKey(
                                              'weekly-distance-bar-$i',
                                            ),
                                            height: 116 * totals[i] / maximum,
                                            decoration: BoxDecoration(
                                              color: g.accent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    labels[i],
                                    style: GabayTheme.labelSmall(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (trips == null) ...[
            const SizedBox(height: 12),
            Text(
              'Saved activity is unavailable.',
              style: GabayTheme.labelSmall(context),
            ),
          ],
        ],
      ),
    );
  }
}
