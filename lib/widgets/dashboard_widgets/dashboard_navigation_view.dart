import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/dashboard_snapshot.dart';
import '../../theme/gabay_theme.dart';
import '../shared/gabay_card.dart';
import '../track/gabay_map_marker.dart';
import '../track/gabay_track_map.dart';

typedef DashboardMapBuilder =
    Widget Function(
      DashboardSnapshot data,
      List<DashboardSnapshot> peers,
      List<LatLng> route,
    );

class DashboardNavigationView extends StatefulWidget {
  const DashboardNavigationView({
    super.key,
    required this.data,
    this.peers = const [],
    this.route = const [],
    this.eta,
    required this.now,
    this.onViewMap,
    this.mapBuilder,
    this.summary,
  });
  final DashboardSnapshot data;
  final List<DashboardSnapshot> peers;
  final List<LatLng> route;
  final String? eta;
  final DateTime now;
  final VoidCallback? onViewMap;
  final DashboardMapBuilder? mapBuilder;
  final Widget? summary;
  @override
  State<DashboardNavigationView> createState() =>
      _DashboardNavigationViewState();
}

class _DashboardNavigationViewState extends State<DashboardNavigationView> {
  TrackMapController? _map;
  bool _follow = true;
  @override
  Widget build(BuildContext context) {
    final data = widget.data, fresh = widget.data.fresh(widget.now);
    final point = data.position ?? data.target;
    final metrics = <({String title, String value, IconData icon})>[
      (
        title: 'Navigation status',
        value: data.status(widget.now),
        icon: Icons.navigation_outlined,
      ),
      (
        title: 'Current heading',
        value: fresh
            ? data.headingLabel
            : data.routeActive
            ? 'Heading unavailable'
            : 'No active route',
        icon: Icons.explore_outlined,
      ),
      (
        title: 'Destination',
        value: data.destinationName,
        icon: Icons.flag_outlined,
      ),
      (
        title: 'Estimated arrival',
        value: !data.routeActive
            ? 'No active route'
            : !fresh
            ? 'ETA unavailable · GPS offline'
            : DashboardSnapshot.clean(widget.eta) ?? 'ETA unavailable',
        icon: Icons.schedule,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GabayCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _DashboardIcon(icon: Icons.directions_walk_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.name} · Navigation overview',
                      style: TextStyle(
                        color: context.gabay.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Estimated arrival',
                      style: TextStyle(
                        color: context.gabay.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      metrics[3].value,
                      style: TextStyle(
                        color: context.gabay.accent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GabayCard(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final battery = Row(
                children: [
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                width: 5,
                                color: context.gabay.accent.withValues(
                                  alpha: .4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Icon(Icons.bolt, color: context.gabay.accent, size: 26),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unavailable',
                          style: TextStyle(
                            color: context.gabay.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Cane Battery',
                          style: TextStyle(
                            color: context.gabay.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final status = Row(
                children: [
                  _DashboardIcon(icon: Icons.directions_walk_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.status(widget.now),
                          style: TextStyle(
                            color: context.gabay.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Navigation status',
                          style: TextStyle(
                            color: context.gabay.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 290 ||
                  MediaQuery.textScalerOf(context).scale(16) > 22) {
                return Column(
                  children: [battery, const SizedBox(height: 20), status],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(child: battery),
                    VerticalDivider(width: 24, color: context.gabay.border),
                    Expanded(child: status),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (widget.summary != null) ...[
          widget.summary!,
          const SizedBox(height: 16),
        ],
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.gabay.accentTint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              data.trackingLabel(widget.now),
              style: TextStyle(
                color: context.gabay.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final two =
                constraints.maxWidth >= 320 &&
                MediaQuery.textScalerOf(context).scale(16) <= 22;
            final width = two
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in [metrics[1], metrics[2]])
                  SizedBox(
                    width: width,
                    child: GabayCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DashboardIcon(icon: item.icon),
                          const SizedBox(height: 8),
                          Text(
                            item.title,
                            style: TextStyle(
                              color: context.gabay.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.value,
                            style: TextStyle(
                              color: context.gabay.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
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
        if (DashboardSnapshot.clean(data.destination) != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '${data.routeActive ? 'Route address' : 'Last saved destination'}: ${data.destination}',
            ),
          ),
        if (widget.eta != null && data.routeActive && fresh)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Walking-route estimate · Updates as your location changes',
            ),
          ),
        const SizedBox(height: 16),
        GabayCard(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Live location & path',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 190,
                  child: point == null
                      ? ColoredBox(
                          color: context.gabay.mapPlaceholder,
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No GPS location yet. Location will appear here when the Navigator shares a valid update.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        )
                      : widget.mapBuilder?.call(
                              data,
                              widget.peers,
                              widget.route,
                            ) ??
                            GabayTrackMap(
                              key: ValueKey(data.uid),
                              initialCamera: CameraPosition(
                                target: point,
                                zoom: 15,
                              ),
                              markers: [
                                for (final peer in widget.peers)
                                  if (peer.uid != data.uid &&
                                      peer.position != null)
                                    GabayMapMarkerData(
                                      id: peer.uid,
                                      position: peer.position!,
                                      kind: GabayMapMarkerKind.navigator,
                                      title: peer.name,
                                    ),
                                if (data.position != null)
                                  GabayMapMarkerData(
                                    id: data.uid,
                                    position: data.position!,
                                    kind: GabayMapMarkerKind.navigator,
                                    title: data.name,
                                    snippet: fresh
                                        ? 'Recent GPS'
                                        : 'Last known GPS',
                                  ),
                                if (data.target != null)
                                  GabayMapMarkerData(
                                    id: 'destination',
                                    position: data.target!,
                                    kind: GabayMapMarkerKind.destination,
                                    title: data.destinationName,
                                  ),
                              ],
                              routePoints: widget.route,
                              breadcrumbPoints: data.points,
                              padding: EdgeInsets.zero,
                              onControllerReady: (controller) {
                                _map = controller;
                              },
                              followTarget: data.position,
                              followUser: _follow && fresh,
                            ),
                ),
              ),
              if (data.locationTime != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Last GPS update: ${data.locationTime!.toLocal().hour.toString().padLeft(2, '0')}:${data.locationTime!.toLocal().minute.toString().padLeft(2, '0')}:${data.locationTime!.toLocal().second.toString().padLeft(2, '0')}',
                  ),
                ),
              const Text('Blue: walking route · Teal: recorded path'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilterChip(
                    label: const Text('Follow location'),
                    selected: _follow,
                    onSelected: point == null
                        ? null
                        : (value) => setState(() => _follow = value),
                  ),
                  TextButton.icon(
                    onPressed: point == null
                        ? null
                        : () => _map?.animateToLatLng(point),
                    icon: const Icon(Icons.my_location),
                    label: const Text('Center map'),
                  ),
                  TextButton.icon(
                    onPressed: widget.onViewMap,
                    style: TextButton.styleFrom(
                      backgroundColor: context.gabay.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    icon: const Icon(Icons.chevron_right, size: 18),
                    label: const Text('View full map'),
                  ),
                ],
              ),
            ],
          ),
        ),
        for (final error in data.errors)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: TextStyle(color: context.gabay.warning),
              ),
            ),
          ),
      ],
    );
  }
}

class _DashboardIcon extends StatelessWidget {
  const _DashboardIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: context.gabay.accentTint,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(icon, size: 22, color: context.gabay.accent),
  );
}
