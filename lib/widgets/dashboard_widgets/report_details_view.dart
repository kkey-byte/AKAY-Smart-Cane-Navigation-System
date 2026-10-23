import 'package:flutter/material.dart';
import '../../models/breadcrumb_trip.dart';
import '../../theme/gabay_theme.dart';
import '../shared/gabay_card.dart';

/// Presentation only: values are supplied by the existing report calculation.
class ReportDetailsView extends StatelessWidget {
  const ReportDetailsView({
    super.key,
    required this.values,
    required this.trips,
  });
  final Map<String, String> values;
  final List<BreadcrumbTrip>? trips;

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
        child: ReportDetailsView(values: values, trips: trips),
      );
    }
    final g = _reportColors(context);
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
        icon: Icons.straighten_rounded,
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
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: g.accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              field.icon,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            field.value,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: g.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            field.label,
                            style: TextStyle(
                              fontSize: 11,
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
        const SizedBox(height: 12),
        Text(
          values['Total Route']!,
          style: TextStyle(fontSize: 12, color: g.textSecondary),
        ),
        const SizedBox(height: 16),
        GabayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This week',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
                                fontSize: 10,
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
                'Daily activity breakdown unavailable.',
                style: TextStyle(color: g.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _heading(context, 'Most Visited Places'),
        const SizedBox(height: 12),
        GabayCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _placeIcon(context),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Visit counts unavailable.',
                  style: TextStyle(color: g.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _heading(context, 'Recent Trips'),
        const SizedBox(height: 12),
        if (trips == null || trips!.isEmpty)
          GabayCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              trips == null
                  ? 'Recorded trips unavailable.'
                  : 'No recorded trips yet.',
              style: TextStyle(color: g.textSecondary, fontSize: 13),
            ),
          ),
        for (final trip in trips ?? <BreadcrumbTrip>[]) ...[
          GabayCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: g.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.name,
                          style: TextStyle(
                            color: g.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${trip.startedAt.toLocal()} • ${trip.isRecording ? 'Recording' : trip.status}',
                          style: TextStyle(
                            color: g.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        Text(
          'Movement duration unavailable. Track recording time does not establish walking time.',
          style: TextStyle(color: g.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 20),
        _heading(context, 'Navigation Events'),
        const SizedBox(height: 12),
        GabayCard(
          child: Text(
            'Device events unavailable.',
            style: TextStyle(color: g.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _heading(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      color: _reportColors(context).textPrimary,
      fontSize: 21,
      fontWeight: FontWeight.w600,
    ),
  );
  Widget _placeIcon(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: _reportColors(context).accent,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.apartment, color: Colors.white, size: 20),
  );
}

GabayThemeExtension _reportColors(BuildContext context) =>
    Theme.of(context).extension<GabayThemeExtension>() ??
    (Theme.of(context).brightness == Brightness.dark
        ? GabayThemeExtension.dark
        : GabayThemeExtension.light);
