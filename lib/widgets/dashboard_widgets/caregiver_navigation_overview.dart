import '../../theme/gabay_typography.dart';
import '../shared/navigator_selection_modal.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/breadcrumb_trip.dart';
import '../../models/dashboard_snapshot.dart';
import '../../services/breadcrumb_service.dart';
import '../../theme/gabay_theme.dart';
import '../shared/gabay_card.dart';
import '../shared/gabay_dashboard_backdrop.dart';
import '../track/gabay_map_marker.dart';
import '../track/gabay_track_map.dart';

class CaregiverNavigationOverview extends StatelessWidget {
  const CaregiverNavigationOverview({
    super.key,
    required this.data,
    required this.now,
    this.picture,
    this.peers = const [],
    this.route = const [],
    this.mapBuilder,
    this.onViewMap,
    this.navigatorOptions = const [],
    this.onNavigatorSelected,
    this.showNavigatorSelector = true,
    this.showProfileSummary = true,
    this.statusHeading = 'Navigator’s current status',
  });
  final DashboardSnapshot data;
  final DateTime now;
  final String? picture;
  final List<DashboardSnapshot> peers;
  final List<LatLng> route;
  final Widget Function(
    DashboardSnapshot,
    List<DashboardSnapshot>,
    List<LatLng>,
  )?
  mapBuilder;
  final VoidCallback? onViewMap;
  final List<({String uid, String name})> navigatorOptions;
  final ValueChanged<String>? onNavigatorSelected;
  final bool showNavigatorSelector;
  final bool showProfileSummary;
  final String statusHeading;

  Future<void> _selectNavigator(BuildContext context) async {
    final uid = await showNavigatorSelectionModal(
      context,
      navigatorOptions: navigatorOptions,
      selectedUid: data.uid,
    );
    if (uid != null && context.mounted) onNavigatorSelected?.call(uid);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final onBackdrop = GabayDashboardBackdrop.active(context);
    final blueCards = onBackdrop || !showProfileSummary;
    final statusSurface = GabayTheme.cardDecoration(context).copyWith(
      boxShadow: onBackdrop
          ? const [
              BoxShadow(
                color: Color(0x26031531),
                blurRadius: 20,
                offset: Offset(0, 7),
              ),
            ]
          : GabayTheme.cardDecoration(context).boxShadow,
    );
    final statusInk = blueCards ? Colors.white : g.accent;
    final statusMuted = blueCards
        ? Colors.white.withValues(alpha: .85)
        : g.textSecondary;
    final statusDivider = blueCards
        ? Colors.white.withValues(alpha: .24)
        : g.border;
    final fresh = data.fresh(now);
    final point = data.position ?? data.target;
    Widget avatar = Icon(
      Icons.person_outline_rounded,
      color: g.accent,
      size: 28,
    );
    try {
      if (picture?.startsWith('data:image/') == true) {
        avatar = Image.memory(
          base64Decode(picture!.split(',').last),
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) =>
              Icon(Icons.person_outline_rounded, color: g.accent),
        );
      } else if (Uri.tryParse(picture ?? '')?.scheme == 'https') {
        avatar = Image.network(
          picture!,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) =>
              Icon(Icons.person_outline_rounded, color: g.accent),
        );
      }
    } catch (_) {
      /* Use the profile placeholder for malformed photo data. */
    }
    final map = point == null
        ? ColoredBox(
            color: g.mapPlaceholder,
            child: Center(
              child: Text(
                'Location unavailable',
                style: TextStyle(color: g.textSecondary),
              ),
            ),
          )
        : mapBuilder?.call(data, peers, route) ??
              GabayTrackMap(
                key: ValueKey(data.uid),
                initialCamera: CameraPosition(target: point, zoom: 15),
                markers: [
                  for (final peer in peers)
                    if (peer.position != null)
                      GabayMapMarkerData(
                        id: peer.uid,
                        position: peer.position!,
                        kind: GabayMapMarkerKind.navigator,
                        title: peer.name,
                      ),
                  if (!peers.any((peer) => peer.uid == data.uid) &&
                      data.position != null)
                    GabayMapMarkerData(
                      id: data.uid,
                      position: data.position!,
                      kind: GabayMapMarkerKind.navigator,
                      title: data.name,
                    ),
                  if (data.target != null)
                    GabayMapMarkerData(
                      id: 'destination',
                      position: data.target!,
                      kind: GabayMapMarkerKind.destination,
                      title: data.destinationName,
                    ),
                ],
                routePoints: route,
                breadcrumbPoints: data.points,
                padding: EdgeInsets.zero,
                onControllerReady: (_) {},
                followTarget: data.position,
                followUser: fresh,
                mutedTiles: true,
              );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          statusHeading,
          style: TextStyle(
            color: onBackdrop
                ? GabayDashboardBackdrop.secondaryColor(context)
                : g.textSecondary,
            fontSize: GabayTypography.supporting,
          ),
        ),
        const SizedBox(height: 10),
        GabayCard(
          decoration: blueCards
              ? statusSurface.copyWith(
                  gradient: GabayTheme.headerGradient,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .22),
                  ),
                )
              : statusSurface,
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              if (showProfileSummary) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: ClipOval(
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: ColoredBox(
                                color: g.accentTint,
                                child: avatar,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.name,
                                style: TextStyle(
                                  color: blueCards
                                      ? Colors.white
                                      : g.textPrimary,
                                  fontWeight: GabayTypography.regular,
                                  fontSize: GabayTypography.cardTitle,
                                ),
                              ),
                              Text(
                                'Navigator',
                                style: TextStyle(
                                  color: blueCards
                                      ? Colors.white.withValues(alpha: .85)
                                      : g.textSecondary,
                                  fontSize: GabayTypography.caption,
                                  fontWeight: GabayTypography.regular,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (blueCards
                                              ? Colors.white
                                              : data.appActive(now)
                                              ? g.success
                                              : g.textSecondary)
                                          .withValues(alpha: .10),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  data.appActive(now)
                                      ? '● Online'
                                      : '○ Offline',
                                  style: TextStyle(
                                    color: blueCards
                                        ? (data.appActive(now)
                                              ? const Color(0xFFBBF7D0)
                                              : Colors.white.withValues(
                                                  alpha: .88,
                                                ))
                                        : data.appActive(now)
                                        ? g.success
                                        : g.textSecondary,
                                    fontSize: GabayTypography.caption,
                                    fontWeight: GabayTypography.regular,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (showNavigatorSelector)
                          IconButton(
                            tooltip: 'Select navigator',
                            onPressed: navigatorOptions.isEmpty
                                ? null
                                : () => _selectNavigator(context),
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: blueCards ? Colors.white : g.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: statusDivider, height: 1),
                const SizedBox(height: 16),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final battery = Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: blueCards
                            ? BoxDecoration(
                                color: Colors.white.withValues(alpha: .13),
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: CircularProgressIndicator(
                                value: 0,
                                backgroundColor: statusInk.withValues(
                                  alpha: .25,
                                ),
                                strokeWidth: 5,
                              ),
                            ),
                            Icon(
                              Icons.bolt_rounded,
                              color: statusInk,
                              size: 32,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FitLabel(
                              text: 'Unavailable',
                              style: TextStyle(
                                color: statusInk,
                                fontWeight: GabayTypography.regular,
                                fontSize: GabayTypography.body,
                              ),
                            ),
                            _FitLabel(
                              text: 'Cane Battery',
                              style: TextStyle(
                                color: statusMuted,
                                fontSize: GabayTypography.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final status = Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: blueCards
                              ? Colors.white.withValues(alpha: .16)
                              : g.accentTint,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.directions_walk_rounded,
                          color: statusInk,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FitLabel(
                              text: data.status(now),
                              style: TextStyle(
                                color: statusInk,
                                fontSize: GabayTypography.body,
                                fontWeight: GabayTypography.regular,
                              ),
                            ),
                            const SizedBox(height: 3),
                            _FitLabel(
                              text: 'Status',
                              style: TextStyle(
                                color: statusMuted,
                                fontSize: GabayTypography.caption,
                                fontWeight: GabayTypography.regular,
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        battery,
                        if (blueCards)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1, color: statusDivider),
                          )
                        else
                          const SizedBox(height: 16),
                        status,
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(child: battery),
                        VerticalDivider(width: 24, color: statusDivider),
                        Expanded(child: status),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _NavigatorTotals(
          key: ValueKey(data.uid),
          uid: data.uid,
          blueCards: blueCards,
        ),
        const SizedBox(height: 16),
        Text(
          'Navigator map',
          style: onBackdrop
              ? GabayDashboardBackdrop.headingStyle(context)
              : TextStyle(
                  color: g.textPrimary,
                  fontSize: GabayTypography.cardTitle,
                  fontWeight: GabayTypography.semibold,
                ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: GabayTheme.headerGradient,
            boxShadow: blueCards || onBackdrop
                ? [
                    BoxShadow(
                      color: g.shadow,
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
            border: Border.all(
              color: onBackdrop
                  ? Colors.white.withValues(alpha: .28)
                  : g.accent.withValues(alpha: .25),
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: SizedBox(
              height: 230,
              child: Stack(
                children: [
                  Positioned.fill(child: map),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: g.surface.withValues(alpha: .95),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          data.position == null
                              ? 'Location unavailable'
                              : fresh
                              ? data.name
                              : 'Last known location',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: GabayTypography.caption,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : g.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: MediaQuery.textScalerOf(context).scale(16) > 22
                        ? 40
                        : 8,
                    right: 8,
                    child: FilledButton(
                      onPressed: onViewMap,
                      style:
                          FilledButton.styleFrom(
                            backgroundColor:
                                onBackdrop &&
                                    GabayDashboardBackdrop.isDark(context)
                                ? GabayColors.primaryBlue
                                : g.accent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            textStyle: const TextStyle(
                              fontSize: GabayTypography.caption,
                              fontWeight: GabayTypography.regular,
                            ),
                          ).copyWith(
                            backgroundBuilder: (context, states, child) =>
                                child ?? const SizedBox.shrink(),
                          ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('View map'),
                          SizedBox(width: 5),
                          Icon(Icons.chevron_right_rounded, size: 17),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _DestinationCard(value: data.destinationName),
      ],
    );
  }
}

class _DestinationCard extends StatefulWidget {
  const _DestinationCard({required this.value});
  final String value;
  @override
  State<_DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<_DestinationCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    return GabayCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97B69).withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color.lerp(const Color(0xFFD97B69), Colors.white, .30)!,
                        const Color(0xFFD97B69),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97B69).withValues(alpha: .18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.flag_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Destination',
                  style: TextStyle(
                    color: g.textSecondary,
                    fontSize: GabayTypography.supporting,
                  ),
                ),
              ),
              IconButton(
                tooltip: _expanded
                    ? 'Collapse destination'
                    : 'Expand destination',
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: g.accent,
                ),
              ),
            ],
          ),
          if (_expanded)
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.textScalerOf(context).scale(14) * 2.8,
              ),
              child: Text(
                widget.value,
                style: TextStyle(
                  color: g.textPrimary,
                  fontSize: GabayTypography.body,
                  height: 1.4,
                ),
              ),
            )
          else
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(14) * 2.8,
              width: double.infinity,
              child: Text(
                widget.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: g.textPrimary,
                  fontSize: GabayTypography.body,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FitLabel extends StatelessWidget {
  const _FitLabel({required this.text, required this.style});
  final String text;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(text, maxLines: 1, softWrap: false, style: style),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.icon,
    required this.title,
    required this.value,
    this.foreground,
    this.statistic = false,
  });
  final IconData icon;
  final String title, value;
  final Color? foreground;
  final bool statistic;
  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final glass = GabayDashboardBackdrop.active(context);
    final ink = glass
        ? GabayDashboardBackdrop.primaryColor(context)
        : foreground;
    final iconAccent = switch (icon) {
      Icons.location_on_outlined => const Color(0xFF8064D8),
      Icons.flag_outlined => const Color(0xFFD97B69),
      _ => const Color(0xFF397BE5),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: glass
                ? iconAccent.withValues(alpha: .10)
                : ink == Colors.white
                ? Colors.white.withValues(alpha: .18)
                : g.accentTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: glass
              ? Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(iconAccent, Colors.white, .30)!,
                        iconAccent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: iconAccent.withValues(alpha: .18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                )
              : Icon(icon, color: ink ?? g.accent, size: 21),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            color: glass
                ? GabayDashboardBackdrop.secondaryColor(context)
                : ink?.withValues(alpha: .88) ?? g.textSecondary,
            fontSize: glass ? 13 : 12,
            fontWeight: glass
                ? GabayTypography.medium
                : GabayTypography.regular,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: ink ?? g.textPrimary,
            fontSize: statistic ? 24 : 15,
            fontWeight: statistic || glass
                ? GabayTypography.medium
                : GabayTypography.regular,
          ),
        ),
      ],
    );
  }
}

class _EqualCards extends StatelessWidget {
  const _EqualCards({required this.children, this.blueStatistics = false});
  final List<Widget> children;
  final bool blueStatistics;
  Widget _card(BuildContext context, int index) => GabayCard(
    decoration: !GabayDashboardBackdrop.active(context) && blueStatistics
        ? GabayTheme.cardDecoration(context).copyWith(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: index == 0
                  ? const [Color(0xFF3B82F6), Color(0xFF2563EB)]
                  : const [Color(0xFFDBEAFE), Color(0xFF93C5FD)],
            ),
            border: Border.all(
              color: context.gabay.accent.withValues(alpha: .15),
            ),
          )
        : null,
    child: children[index],
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 280 ||
          MediaQuery.textScalerOf(context).scale(16) > 24) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _card(context, i),
              ),
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _card(context, 0)),
            const SizedBox(width: 12),
            Expanded(child: _card(context, 1)),
          ],
        ),
      );
    },
  );
}

class _NavigatorTotals extends StatefulWidget {
  const _NavigatorTotals({
    super.key,
    required this.uid,
    this.blueCards = false,
  });
  final String uid;
  final bool blueCards;
  @override
  State<_NavigatorTotals> createState() => _NavigatorTotalsState();
}

class _NavigatorTotalsState extends State<_NavigatorTotals> {
  Stream<List<BreadcrumbTrip>>? _trips;
  @override
  void initState() {
    super.initState();
    try {
      _trips = BreadcrumbService.instance.repository.watchTrips(widget.uid);
    } catch (_) {
      /* Totals stay unavailable until history can be loaded. */
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<BreadcrumbTrip>>(
    stream: _trips,
    builder: (context, snapshot) {
      final trips = snapshot.hasError ? null : snapshot.data;
      double meters = 0;
      for (final trip in trips ?? <BreadcrumbTrip>[]) {
        for (var i = 1; i < trip.points.length; i++) {
          final a = trip.points[i - 1], b = trip.points[i];
          meters += Geolocator.distanceBetween(
            a.latitude,
            a.longitude,
            b.latitude,
            b.longitude,
          );
        }
      }
      return Semantics(
        label:
            'Totals from available recorded routes. GPS distance is approximate.',
        child: _EqualCards(
          blueStatistics: widget.blueCards,
          children: [
            _Detail(
              icon: Icons.location_on_outlined,
              title: 'Total Distance',
              foreground: widget.blueCards ? Colors.white : null,
              statistic: widget.blueCards,
              value:
                  trips == null || !trips.any((trip) => trip.points.isNotEmpty)
                  ? '—'
                  : '${(meters / 1000).toStringAsFixed(2)} km',
            ),
            _Detail(
              icon: Icons.route_outlined,
              title: 'Total Route',
              foreground: widget.blueCards ? const Color(0xFF123B70) : null,
              statistic: widget.blueCards,
              value: trips == null ? '—' : '${trips.length}',
            ),
          ],
        ),
      );
    },
  );
}
