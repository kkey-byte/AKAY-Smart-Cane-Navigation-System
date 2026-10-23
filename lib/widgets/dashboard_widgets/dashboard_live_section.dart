import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/dashboard_snapshot.dart';
import '../../models/pairing.dart';
import '../../services/app_session_service.dart';
import '../../services/breadcrumb_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/map_place_service.dart';
import '../../services/navigator_location_service.dart';
import '../../services/pairing_service.dart';
import '../../services/route_timeline_tracker.dart';
import '../../services/vi_navigation_session.dart';
import '../shared/gabay_card.dart';
import 'dashboard_navigation_view.dart';
import 'recorded_reports.dart';

class DashboardLiveSection extends StatefulWidget {
  const DashboardLiveSection({
    super.key,
    required this.caregiver,
    required this.onViewMap,
    this.service,
    this.pairing,
    this.routeLoader,
    this.mapBuilder,
  });
  final bool caregiver;
  final VoidCallback onViewMap;
  final DashboardService? service;
  final PairingService? pairing;
  final Future<OsrmRouteGeometry?> Function(LatLng origin, LatLng target)?
  routeLoader;
  final DashboardMapBuilder? mapBuilder;
  @override
  State<DashboardLiveSection> createState() => _DashboardLiveSectionState();
}

class _DashboardLiveSectionState extends State<DashboardLiveSection> {
  late final DashboardService _service;
  late final PairingService _pairing;
  late final int _revision;
  final _subscriptions = <String, StreamSubscription<DashboardSnapshot>>{};
  final _data = <String, DashboardSnapshot>{};
  final _errors = <String, String>{};
  List<PairingConnection>? _connections;
  StreamSubscription<List<PairingConnection>>? _links;
  DashboardPresenceReporter? _presence;
  Timer? _clock;
  String? _selected, _linkError;
  OsrmRouteGeometry? _route;
  LatLng? _routeOrigin, _routeTarget;
  DateTime? _routeTime;
  bool _routing = false;
  int _routeGeneration = 0;
  bool get _valid => _revision == AppSessionService.instance.identityRevision;
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DashboardService.instance;
    _pairing = widget.pairing ?? PairingService.instance;
    _revision = AppSessionService.instance.identityRevision;
    AppSessionService.instance.addListener(_sessionChanged);
    if (widget.caregiver) {
      _listenConnections();
    } else {
      _selected = _service.currentUid;
      if (_selected != null) _watch(_selected!);
      _presence = DashboardPresenceReporter(_service)..start();
      NavigatorLocationService.instance.addListener(_localChanged);
      ViNavigationSession.instance.addListener(_localChanged);
      RouteTimelineTracker.instance.addListener(_localChanged);
      BreadcrumbService.instance.addListener(_localChanged);
    }
    _clock = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && _valid) {
        setState(() {});
        _updateRoute();
      }
    });
  }

  void _sessionChanged() {
    if (!_valid) {
      _routeGeneration++;
      for (final sub in _subscriptions.values) {
        unawaited(sub.cancel());
      }
      _subscriptions.clear();
      unawaited(_links?.cancel());
      if (mounted) {
        setState(() {
          _data.clear();
          _connections = null;
          _selected = null;
          _route = null;
          _linkError = 'Account changed. Reopen your dashboard.';
        });
      }
    }
  }

  void _listenConnections() {
    unawaited(_links?.cancel());
    _links = _pairing.watchConnections().listen(
      (rows) {
        if (!mounted || !_valid) return;
        final active = rows.where((row) => row.status == 'active').toList();
        final uids = active.map((row) => row.navigatorUid).toSet();
        for (final uid in _subscriptions.keys.toList()) {
          if (!uids.contains(uid)) {
            unawaited(_subscriptions.remove(uid)?.cancel());
            _data.remove(uid);
            _errors.remove(uid);
          }
        }
        if (!uids.contains(_selected)) {
          _selected = active.firstOrNull?.navigatorUid;
          _resetRoute();
        }
        setState(() {
          _connections = active;
          _linkError = null;
        });
        for (final uid in uids) {
          if (!_subscriptions.containsKey(uid)) _watch(uid);
        }
      },
      onError: (Object _) {
        if (mounted && _valid) {
          for (final sub in _subscriptions.values) {
            unawaited(sub.cancel());
          }
          _subscriptions.clear();
          setState(() {
            _data.clear();
            _connections = null;
            _selected = null;
            _resetRoute();
            _linkError =
                'Connected Navigators could not be loaded. Check your connection and access.';
          });
        }
      },
    );
  }

  void _watch(String uid) {
    _subscriptions[uid] = _service
        .watch(uid)
        .listen(
          (data) {
            if (!mounted || !_valid) return;
            if (widget.caregiver &&
                !(_connections?.any((row) => row.navigatorUid == uid) ??
                    false)) {
              return;
            }
            if (data.uid != uid) {
              setState(() {
                _data.remove(uid);
                _errors[uid] = 'Dashboard identity could not be verified.';
              });
              return;
            }
            setState(() {
              _data[uid] = data;
              _errors.remove(uid);
            });
            _updateRoute();
          },
          onError: (Object _) {
            if (!mounted || !_valid) return;
            setState(() {
              _data.remove(uid);
              _errors[uid] =
                  'Saved dashboard data is unavailable. Check your connection or pairing access.';
              if (_selected == uid) _resetRoute();
            });
          },
        );
  }

  void _localChanged() {
    if (mounted && _valid) {
      setState(() {});
      _updateRoute();
    }
  }

  DashboardSnapshot? get _current {
    final uid = _selected;
    if (uid == null) return null;
    final saved = _data[uid];
    if (widget.caregiver) return saved;
    final location = NavigatorLocationService.instance,
        session = ViNavigationSession.instance,
        timeline = RouteTimelineTracker.instance;
    final fix = location.lastPosition;
    final localActive = session.isNavigating;
    final arrived = timeline.entries.lastOrNull?.isArrived == true;
    final destination = timeline.activeDestination;
    return DashboardSnapshot(
      uid: uid,
      name:
          DashboardSnapshot.clean(AppSessionService.instance.displayName) ??
          saved?.name ??
          'Navigator',
      position: location.livePosition ?? saved?.position,
      locationTime: fix?.timestamp ?? saved?.locationTime,
      heading: location.headingDegrees ?? saved?.heading,
      target: localActive || arrived
          ? destination?.latLng ?? saved?.target
          : saved?.target,
      destination: localActive || arrived
          ? destination == null
                ? session.destination ?? saved?.destination
                : '${destination.displayName}, ${destination.address}'
          : saved?.destination,
      routeStatus: localActive
          ? 'Active'
          : arrived
          ? 'Completed'
          : saved?.routeStatus,
      routeActive: localActive || (!arrived && (saved?.routeActive ?? false)),
      endedAt: arrived ? timeline.entries.last.timestamp : saved?.endedAt,
      presence:
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed
          ? 'active'
          : 'inactive',
      presenceTime: DateTime.now(),
      points: BreadcrumbService.instance.points.isNotEmpty
          ? BreadcrumbService.instance.points
                .map((point) => point.location)
                .toList()
          : saved?.points ?? const [],
      errors: [...saved?.errors ?? [], if (_errors[uid] != null) _errors[uid]!],
    );
  }

  void _resetRoute() {
    _routeGeneration++;
    _route = null;
    _routeOrigin = null;
    _routeTarget = null;
    _routeTime = null;
    _routing = false;
  }

  Future<void> _updateRoute() async {
    final data = _current;
    final now = DateTime.now();
    if (data == null || !data.routeActive) {
      if ((_route != null || _routing) && mounted) setState(_resetRoute);
      return;
    }
    if ((_route != null || _routing) && _routeTarget != data.target) {
      setState(_resetRoute);
    }
    if (!data.fresh(now) ||
        data.position == null ||
        data.target == null ||
        _routing) {
      return;
    }
    final same = _routeTarget == data.target;
    if (same &&
        _routeTime != null &&
        (now.difference(_routeTime!) < const Duration(minutes: 1) ||
            (_route != null &&
                _routeOrigin != null &&
                Geolocator.distanceBetween(
                      _routeOrigin!.latitude,
                      _routeOrigin!.longitude,
                      data.position!.latitude,
                      data.position!.longitude,
                    ) <
                    25))) {
      return;
    }
    final version = ++_routeGeneration;
    _routing = true;
    _routeTime = now;
    _routeTarget = data.target;
    _routeOrigin = data.position;
    try {
      final route =
          await (widget.routeLoader ??
              MapPlaceService.instance.fetchWalkingRoute)(
            data.position!,
            data.target!,
          );
      if (mounted && _valid && version == _routeGeneration) {
        setState(() => _route = route);
      }
    } catch (_) {
      if (mounted && version == _routeGeneration) setState(() => _route = null);
    } finally {
      if (version == _routeGeneration) _routing = false;
    }
  }

  @override
  void dispose() {
    _routeGeneration++;
    _clock?.cancel();
    unawaited(_links?.cancel());
    for (final sub in _subscriptions.values) {
      unawaited(sub.cancel());
    }
    _presence?.dispose();
    AppSessionService.instance.removeListener(_sessionChanged);
    if (!widget.caregiver) {
      NavigatorLocationService.instance.removeListener(_localChanged);
      ViNavigationSession.instance.removeListener(_localChanged);
      RouteTimelineTracker.instance.removeListener(_localChanged);
      BreadcrumbService.instance.removeListener(_localChanged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_valid || _linkError != null) {
      return GabayCard(
        child: Column(
          children: [
            Text(_linkError ?? 'Account changed. Reopen your dashboard.'),
            if (_valid)
              TextButton(
                onPressed: _listenConnections,
                child: const Text('Retry'),
              ),
          ],
        ),
      );
    }
    if (widget.caregiver && _connections == null) {
      return const GabayCard(child: Text('Loading connected Navigators…'));
    }
    if (widget.caregiver && _connections!.isEmpty) {
      return const GabayCard(
        child: Text(
          'No paired Navigators yet. Use Add / Pair New Navigator below to start monitoring.',
        ),
      );
    }
    final selected = _current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.caregiver) ...[
          DropdownButtonFormField<String>(
            key: ValueKey(_selected),
            initialValue: _selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Navigator to monitor',
            ),
            items: [
              for (final row in _connections!)
                DropdownMenuItem(
                  value: row.navigatorUid,
                  child: Text(row.navigatorName),
                ),
            ],
            onChanged: (uid) {
              setState(() {
                _selected = uid;
                _resetRoute();
              });
              _updateRoute();
            },
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final row in _connections!)
                ChoiceChip(
                  label: Text(
                    '${row.navigatorName} · ${_data[row.navigatorUid]?.status(DateTime.now()) ?? 'Loading'}',
                  ),
                  selected: _selected == row.navigatorUid,
                  onSelected: (_) {
                    setState(() {
                      _selected = row.navigatorUid;
                      _resetRoute();
                    });
                    _updateRoute();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_errors[_selected] != null && widget.caregiver)
          GabayCard(child: Text(_errors[_selected]!)),
        if (selected != null)
          DashboardNavigationView(
            data: selected,
            peers: _data.values.toList(),
            route: _route?.points ?? const [],
            eta: _route?.durationLabel,
            now: DateTime.now(),
            mapBuilder: widget.mapBuilder,
            onViewMap: widget.onViewMap,
            summary: widget.caregiver
                ? null
                : const RecordedReports(caregiver: false, compact: true),
          )
        else
          GabayCard(
            child: Text(
              _errors[_selected] ?? 'Loading navigation and shared location…',
            ),
          ),
      ],
    );
  }
}
