import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/linked_navigator.dart';
import '../../models/route_plan.dart';
import '../../models/route_timeline_entry.dart';
import '../../services/app_session_service.dart';
import '../../theme/gabay_theme.dart';
import 'route_timeline_panel.dart';

enum DestinationPanelTab { navigationDetails, routeTimeline }

class EtaCard extends StatefulWidget {
  const EtaCard({
    super.key,
    required this.route,
    required this.timelineEntries,
    required this.currentLocationAddress,
    required this.onDragDismiss,
    required this.onCancelDestination,
  });

  final RoutePlanResult route;
  final List<RouteTimelineEntry> timelineEntries;
  final String currentLocationAddress;
  final VoidCallback onDragDismiss;
  final VoidCallback onCancelDestination;

  @override
  State<EtaCard> createState() => _EtaCardState();
}

class _EtaCardState extends State<EtaCard> {
  DestinationPanelTab _tab = DestinationPanelTab.navigationDetails;
  double _dragOffset = 0;

  static const _dismissThreshold = 72.0;

  @override
  void didUpdateWidget(covariant EtaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.destination.id != widget.route.destination.id) {
      _dragOffset = 0;
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, 220.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_dragOffset > _dismissThreshold || velocity > 650) {
      widget.onDragDismiss();
      setState(() => _dragOffset = 0);
      return;
    }
    setState(() => _dragOffset = 0);
  }

  String get _destinationLabel {
    final destination = widget.route.destination;
    if (destination.address.isEmpty) return destination.name;
    if (destination.address.contains(destination.name)) {
      return destination.address;
    }
    return '${destination.name}, ${destination.address}';
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final fade = (1 - (_dragOffset / 180)).clamp(0.35, 1.0);

    return Transform.translate(
      offset: Offset(0, _dragOffset),
      child: Opacity(
        opacity: fade,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            decoration: BoxDecoration(
              color: g.surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: g.shadow,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onVerticalDragUpdate: _onVerticalDragUpdate,
                  onVerticalDragEnd: _onVerticalDragEnd,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: g.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      _SegmentedTabs(
                        selected: _tab,
                        onChanged: (tab) => setState(() => _tab = tab),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_tab == DestinationPanelTab.navigationDetails)
                  _NavigationDetailsTab(
                    route: widget.route,
                    currentLocation: widget.currentLocationAddress,
                    destinationLabel: _destinationLabel,
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: RouteTimelinePanel(
                        entries: widget.timelineEntries,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: widget.onCancelDestination,
                    style: FilledButton.styleFrom(
                      backgroundColor: g.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'Cancel Destination',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationDetailsTab extends StatelessWidget {
  const _NavigationDetailsTab({
    required this.route,
    required this.currentLocation,
    required this.destinationLabel,
  });

  final RoutePlanResult route;
  final String currentLocation;
  final String destinationLabel;

  String get _navigatorDisplayName {
    if (route.navigator.id == LinkedNavigatorService.selfNavigator.id) {
      final sessionName = AppSessionService.instance.displayName?.trim();
      if (sessionName != null && sessionName.isNotEmpty) return sessionName;
      final email = AppSessionService.instance.email?.trim();
      if (email != null && email.isNotEmpty) {
        final local = email.split('@').first.trim();
        if (local.isNotEmpty) return local;
      }
    }
    final fromRoute = route.navigator.name.trim();
    if (fromRoute.isNotEmpty) return fromRoute;
    return 'Navigator';
  }

  ImageProvider? get _navigatorAvatar {
    final url = AppSessionService.instance.profilePicture?.trim();
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        final comma = url.indexOf(',');
        final raw = comma >= 0 ? url.substring(comma + 1) : url;
        return MemoryImage(base64Decode(raw));
      } catch (_) {
        return null;
      }
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return NetworkImage(url);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final avatar = _navigatorAvatar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: g.accentTint,
              backgroundImage: avatar,
              child: avatar == null
                  ? Icon(Icons.person_rounded, color: g.accent)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _navigatorDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: g.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Navigator',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: g.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: g.border.withValues(alpha: 0.8)),
        const SizedBox(height: 16),
        _LocationDestinationRow(
          currentLocation: currentLocation,
          destinationLabel: destinationLabel,
        ),
        const SizedBox(height: 18),
        _MetricsRow(route: route),
      ],
    );
  }
}

class _LocationDestinationRow extends StatelessWidget {
  const _LocationDestinationRow({
    required this.currentLocation,
    required this.destinationLabel,
  });

  final String currentLocation;
  final String destinationLabel;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Location',
                style: GabayTheme.labelSmall(context).copyWith(fontSize: 11),
              ),
              const SizedBox(height: 6),
              Text(
                currentLocation,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: g.textPrimary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Destination',
                style: GabayTheme.labelSmall(context).copyWith(fontSize: 11),
              ),
              const SizedBox(height: 6),
              Text(
                destinationLabel,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: g.textPrimary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.route});

  final RoutePlanResult route;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _metric(
          context,
          icon: Icons.schedule_rounded,
          label: 'ETA',
          value: route.estimatedTime,
        ),
        _divider(context),
        _metric(
          context,
          icon: Icons.place_outlined,
          label: 'Distance',
          value: route.estimatedDistance,
        ),
        _divider(context),
        _metric(
          context,
          icon: Icons.access_time_rounded,
          label: 'Trip Started',
          value: route.formattedTripStarted,
        ),
      ],
    );
  }

  Widget _metric(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final g = context.gabay;

    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 22, color: g.accent),
          const SizedBox(height: 8),
          Text(
            label,
            style: GabayTheme.labelSmall(context).copyWith(fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: g.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      width: 1,
      height: 56,
      color: context.gabay.border,
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.selected,
    required this.onChanged,
  });

  final DestinationPanelTab selected;
  final ValueChanged<DestinationPanelTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: g.chipBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabChip(
              label: 'Navigation Details',
              selected: selected == DestinationPanelTab.navigationDetails,
              onTap: () => onChanged(DestinationPanelTab.navigationDetails),
            ),
          ),
          Expanded(
            child: _TabChip(
              label: 'Route Timeline',
              selected: selected == DestinationPanelTab.routeTimeline,
              onTap: () => onChanged(DestinationPanelTab.routeTimeline),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? g.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : g.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small floating control to reopen the collapsed destination panel.
class ReopenEtaButton extends StatelessWidget {
  const ReopenEtaButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Material(
      color: g.surface,
      elevation: 6,
      shadowColor: g.shadow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: g.accent.withValues(alpha: 0.2)),
          ),
          child: Icon(Icons.info_outline_rounded, color: g.accent, size: 26),
        ),
      ),
    );
  }
}
