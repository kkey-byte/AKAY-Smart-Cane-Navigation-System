import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/breadcrumb_trip.dart';
import '../../pages/shared/breadcrumb_history_page.dart';
import '../../services/breadcrumb_service.dart';
import '../../theme/gabay_theme.dart';
import '../../theme/gabay_typography.dart';
import '../shared/gabay_card.dart';
import 'breadcrumb_trip_tile.dart' show breadcrumbStatus;

/// Compact record cards open their recorded route in a scrollable modal.
class BreadcrumbTripRecords extends StatefulWidget {
  const BreadcrumbTripRecords({
    super.key,
    required this.trips,
    required this.localOwner,
    this.watchTrip,
  });
  final List<BreadcrumbTrip> trips;
  final bool localOwner;
  final Stream<BreadcrumbTrip?> Function(String, String)? watchTrip;
  @override
  State<BreadcrumbTripRecords> createState() => _BreadcrumbTripRecordsState();
}

class _BreadcrumbTripRecordsState extends State<BreadcrumbTripRecords> {
  String? _selectedId;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final two =
            constraints.maxWidth >= 300 &&
            MediaQuery.textScalerOf(context).scale(14) <= 20;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final trip in widget.trips)
              SizedBox(
                width: two
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth,
                child: _record(context, trip, _selectedId == trip.id),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openTrip(BreadcrumbTrip trip) async {
    if (_selectedId != null) return;
    setState(() => _selectedId = trip.id);
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: dialogContext.gabay.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 760,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * .9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          namesRoute: true,
                          header: true,
                          child: Text(
                            trip.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GabayTheme.bodyLarge(dialogContext),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close trip details',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: BreadcrumbTripPage(
                      key: ValueKey('${trip.ownerId}:${trip.id}'),
                      trip: trip,
                      localOwner: widget.localOwner,
                      embedded: true,
                      watchTrip: widget.watchTrip,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _selectedId = null);
    }
  }

  Widget _record(BuildContext context, BreadcrumbTrip trip, bool selected) {
    final g = context.gabay;
    final distance = trip.pointCount == 0
        ? 'No GPS points yet'
        : trip.distanceMeters < 1000
        ? '${trip.distanceMeters.toStringAsFixed(0)} m recorded'
        : '${(trip.distanceMeters / 1000).toStringAsFixed(2)} km recorded';
    final date = trip.startedAt.toLocal().toString().substring(0, 16);
    return Semantics(
      selected: selected,
      child: GabayCard(
        padding: const EdgeInsets.all(16),
        semanticLabel: '${trip.name}, $date. View recorded route',
        onTap: () => unawaited(_openTrip(trip)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: g.accentTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    trip.sourceType == 'cane_gps'
                        ? Icons.accessible_forward_rounded
                        : Icons.directions_walk_rounded,
                    size: 20,
                    color: g.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: g.textPrimary,
                      fontSize: GabayTypography.cardBody,
                      fontWeight: GabayTypography.semibold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              distance,
              style: TextStyle(
                color: g.textPrimary,
                fontSize: GabayTypography.cardBody,
                fontWeight: GabayTypography.semibold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date,
              style: TextStyle(
                color: g.textSecondary,
                fontSize: GabayTypography.caption,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${trip.sourceType == 'cane_gps' ? 'Cane GPS' : 'Phone GPS'} · ${trip.pointCount} points',
              style: TextStyle(
                color: g.textSecondary,
                fontSize: GabayTypography.caption,
              ),
            ),
            const Divider(height: 24),
            Text(
              breadcrumbStatus(
                trip,
                DateTime.now(),
                connected: BreadcrumbService.instance.connected,
              ),
              style: TextStyle(
                color: g.textSecondary,
                fontSize: GabayTypography.caption,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'View route',
                    style: TextStyle(
                      color: g.accent,
                      fontSize: GabayTypography.caption,
                    ),
                  ),
                ),
                Icon(Icons.open_in_full_rounded, color: g.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
