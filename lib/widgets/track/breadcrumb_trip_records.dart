import '../shared/gabay_modal_motion.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/breadcrumb_trip.dart';
import '../../pages/shared/breadcrumb_history_page.dart';
import '../../theme/gabay_theme.dart';
import '../shared/gabay_card.dart';

/// Compact record cards open their recorded route in a scrollable modal.
class BreadcrumbTripRecords extends StatefulWidget {
  const BreadcrumbTripRecords({
    super.key,
    required this.trips,
    required this.localOwner,
    this.watchTrip,
    this.heading,
    this.controls,
    this.dataAvailable = true,
  });
  final List<BreadcrumbTrip> trips;
  final bool localOwner;
  final String? heading;
  final Widget? controls;
  final bool dataAvailable;
  final Stream<BreadcrumbTrip?> Function(String, String)? watchTrip;
  @override
  State<BreadcrumbTripRecords> createState() => _BreadcrumbTripRecordsState();
}

class _BreadcrumbTripRecordsState extends State<BreadcrumbTripRecords> {
  String? _selectedId;
  List<BreadcrumbTrip> get _ordered =>
      [...widget.trips]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: widget.heading == null
                  ? const SizedBox()
                  : Text(
                      widget.heading!,
                      style: GabayTheme.sectionTitle(context),
                    ),
            ),
            if (widget.trips.isNotEmpty)
              TextButton(onPressed: _viewAll, child: const Text('View All')),
          ],
        ),
        if (widget.heading != null) const SizedBox(height: 12),
        if (widget.controls != null) ...[
          widget.controls!,
          const SizedBox(height: 12),
        ],
        if (widget.heading != null &&
            widget.dataAvailable &&
            widget.trips.isEmpty)
          GabayCard(
            child: Text(
              'No recorded tracks yet.',
              style: GabayTheme.bodyMedium(context),
            ),
          ),
        for (final trip in _ordered.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _record(context, trip, _selectedId == trip.id),
          ),
      ],
    );
  }

  Future<void> _viewAll() => showDialog<void>(
    animationStyle: gabayModalAnimation(context),
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * .8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent Trips',
                      style: GabayTheme.sectionTitle(dialogContext),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close recent trips',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.trips.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => _record(
                    dialogContext,
                    _ordered[index],
                    _selectedId == _ordered[index].id,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _openTrip(BreadcrumbTrip trip) async {
    if (_selectedId != null) return;
    setState(() => _selectedId = trip.id);
    try {
      await showDialog<void>(
        animationStyle: gabayModalAnimation(context),
        context: context,
        builder: (dialogContext) => Dialog(
          clipBehavior: Clip.antiAlias,
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
        ? '${trip.distanceMeters.toStringAsFixed(0)} m'
        : '${(trip.distanceMeters / 1000).toStringAsFixed(2)} km';
    final date = trip.startedAt.toLocal().toString().substring(0, 16);
    return SizedBox(
      height:
          112 +
          (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(
                0,
                double.infinity,
              ) *
              6,
      child: Semantics(
        selected: selected,
        child: GabayCard(
          padding: const EdgeInsets.all(14),
          semanticLabel: '${trip.name}, $date. View recorded route',
          onTap: () => unawaited(_openTrip(trip)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: g.accentTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  trip.sourceType == 'cane_gps'
                      ? Icons.accessible_forward_rounded
                      : Icons.directions_walk_rounded,
                  size: 22,
                  color: g.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: g.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$date · $distance',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: g.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'View route',
                      style: TextStyle(
                        color: g.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: g.accent, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
