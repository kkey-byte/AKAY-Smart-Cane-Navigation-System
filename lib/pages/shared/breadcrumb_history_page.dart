import 'pairing_management_page.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/breadcrumb_trip.dart';
import '../../services/breadcrumb_service.dart';
import '../../theme/gabay_theme.dart';
import '../../widgets/shared/floating_bottom_nav_shell.dart';
import '../../widgets/track/gabay_map_marker.dart';
import '../../widgets/track/gabay_track_map.dart';
import '../../widgets/track/breadcrumb_trip_tile.dart';

class BreadcrumbHistoryPage extends StatefulWidget {
  const BreadcrumbHistoryPage({super.key, required this.caregiver});
  final bool caregiver;
  @override
  State<BreadcrumbHistoryPage> createState() => _BreadcrumbHistoryPageState();
}

class _BreadcrumbHistoryPageState extends State<BreadcrumbHistoryPage> {
  final service = BreadcrumbService.instance;
  StreamSubscription<User?>? _auth;
  StreamSubscription<Map<String, String>>? _linksSubscription;
  StreamSubscription<List<BreadcrumbTrip>>? _tripsSubscription;
  Map<String, String> _links = {};
  List<BreadcrumbTrip> _remote = [];
  String? _uid;
  String? _owner;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  int _historyLimit = 100;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    service.addListener(_refresh);
    unawaited(service.initialize());
    _auth = FirebaseAuth.instance.authStateChanges().listen(_accountChanged);
    _clock = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _accountChanged(User? user) {
    _linksSubscription?.cancel();
    _tripsSubscription?.cancel();
    _uid = user?.uid;
    _owner = null;
    _remote = [];
    _links = {};
    _error = null;
    _loading = user != null;
    if (user == null) {
      _refresh();
      return;
    }
    if (!widget.caregiver) {
      _watchOwner(user.uid);
    } else {
      _linksSubscription = service.repository
          .watchLinks(user.uid)
          .listen(
            (links) {
              if (!mounted || _uid != user.uid) return;
              _links = links;
              if (!_links.containsKey(_owner)) {
                _watchOwner(links.keys.firstOrNull);
              }
              _loading = false;
              _refresh();
            },
            onError: (Object error) {
              _watchOwner(null);
              _links = {};
              _error =
                  'Unable to load shared patients. Check your connection and access.';
              _loading = false;
              _refresh();
            },
          );
    }
    _refresh();
  }

  void _watchOwner(String? owner) {
    _tripsSubscription?.cancel();
    if (_owner != owner) _historyLimit = 100;
    _owner = owner;
    _remote = [];
    _error = null;
    _loading = owner != null;
    if (owner == null) return;
    _tripsSubscription = service.repository
        .watchTrips(owner, limit: _historyLimit)
        .listen(
          (trips) {
            if (!mounted || _owner != owner) return;
            setState(() {
              _remote = trips;
              _loading = false;
              _error = null;
            });
          },
          onError: (Object error) {
            if (!mounted || _owner != owner) return;
            setState(() {
              _remote = [];
              _loading = false;
              _error =
                  'Unable to load shared tracks. Access may have been removed, or the connection is unavailable.';
            });
          },
        );
  }

  List<BreadcrumbTrip> get _trips {
    final map = {for (final trip in _remote) trip.id: trip};
    if (!widget.caregiver && service.recorder?.ownerId == _uid) {
      for (final trip in service.trips) {
        map[trip.id] = trip;
      }
    }
    return map.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PairingManagementPage(caregiver: widget.caregiver),
      ),
    );
  }

  Future<void> _manageShares() async {
    final uid = _uid;
    if (uid == null) return;
    final stream = service.repository.watchShares(uid);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Caregivers with access'),
        content: SizedBox(
          width: 400,
          child: StreamBuilder<Map<String, String>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Unable to load access. Please try again.');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return const Text('No caregivers have access yet.');
              }
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: snapshot.data!.entries
                      .map(
                        (entry) => ListTile(
                          title: Text(entry.value),
                          trailing: IconButton(
                            tooltip: 'Remove access for ${entry.value}',
                            icon: const Icon(Icons.person_remove),
                            onPressed: () async {
                              try {
                                await service.repository
                                    .revoke(uid, entry.key)
                                    .timeout(const Duration(seconds: 12));
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Access could not be removed. Try again.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _auth?.cancel();
    _linksSubscription?.cancel();
    _tripsSubscription?.cancel();
    _clock?.cancel();
    service.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trips = _trips;
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Breadcrumb tracks')),
      backgroundColor: context.gabay.scaffoldBackground,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            GabayNavMetrics.overlayBottom(context) + 24,
          ),
          children: [
            Text(
              widget.caregiver ? 'Patient tracks' : 'My tracks',
              style: GabayTheme.sectionTitle(context),
            ),
            const SizedBox(height: 12),
            if (!service.connected)
              const Text(
                'Cloud connection unavailable. Showing saved data; live updates will resume when connected.',
              ),
            if (_uid == null)
              const Text('Sign in to view and record tracks.')
            else if (widget.caregiver) ...[
              TextButton(
                onPressed: _share,
                child: const Text(
                  'Manage navigator invitations and connections',
                ),
              ),
              if (_links.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: ValueKey(_owner),
                  initialValue: _owner,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Patient'),
                  items: _links.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _watchOwner(value)),
                ),
              if (!_loading && _links.isEmpty && _error == null)
                const Text(
                  'No patients have shared their tracks with you yet.',
                ),
            ] else ...[
              const Text(
                'Your daily path records automatically while signed in, even without a destination. You can pause here. Shared caregivers can view your saved tracks.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => service.isRecording
                            ? service.stop()
                            : service.start(),
                      ),
                icon: Icon(
                  service.isRecording ? Icons.stop : Icons.fiber_manual_record,
                ),
                label: Text(
                  _busy
                      ? 'Please wait…'
                      : service.isRecording
                      ? 'Pause and save track'
                      : 'Resume recording',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : _share,
                    child: const Text('Share with caregiver'),
                  ),
                  TextButton(
                    onPressed: _manageShares,
                    child: const Text('Manage access'),
                  ),
                ],
              ),
              if (service.error != null)
                Text(
                  service.error!,
                  style: TextStyle(color: context.gabay.warning),
                ),
              if (service.recorder?.hasPending == true)
                TextButton(
                  onPressed: () => unawaited(service.recorder!.sync()),
                  child: const Text('Saved on device · Sync now'),
                ),
            ],
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: context.gabay.danger)),
              TextButton(
                onPressed: () =>
                    _accountChanged(FirebaseAuth.instance.currentUser),
                child: const Text('Retry'),
              ),
            ],
            if (_loading && trips.isEmpty) const LinearProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Current and previous tracks',
              style: GabayTheme.sectionTitle(context),
            ),
            if (trips.isEmpty && !_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No recorded tracks yet.'),
              ),
            for (final trip in trips)
              BreadcrumbTripTile(
                trip: trip,
                now: now,
                connected: service.connected,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BreadcrumbTripPage(
                      trip: trip,
                      localOwner: !widget.caregiver,
                    ),
                  ),
                ),
              ),
            if (_remote.length >= _historyLimit)
              TextButton(
                onPressed: () => setState(() {
                  _historyLimit += 100;
                  _watchOwner(_owner);
                }),
                child: const Text('Load older tracks'),
              ),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime value) => value.toLocal().toString().substring(0, 16);

class BreadcrumbTripPage extends StatefulWidget {
  const BreadcrumbTripPage({
    super.key,
    required this.trip,
    required this.localOwner,
  });
  final BreadcrumbTrip trip;
  final bool localOwner;
  @override
  State<BreadcrumbTripPage> createState() => _BreadcrumbTripPageState();
}

class _BreadcrumbTripPageState extends State<BreadcrumbTripPage> {
  final service = BreadcrumbService.instance;
  StreamSubscription<BreadcrumbTrip?>? _subscription;
  Timer? _clock;
  BreadcrumbTrip? _trip;
  String? _error;
  bool _follow = true;
  TrackMapController? _map;
  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    service.addListener(_localUpdate);
    _subscription = service.repository
        .watchTrip(widget.trip.ownerId, widget.trip.id)
        .listen(
          (match) {
            if (!mounted) return;
            setState(() {
              _trip = match;
              _error = match == null
                  ? 'This track is no longer available.'
                  : null;
            });
            _localUpdate();
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _trip = null;
              _error =
                  'Track access is unavailable. Check your connection or ask the navigator to share again.';
            });
            _localUpdate();
          },
        );
    _localUpdate();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  void _localUpdate() {
    if (!mounted ||
        !widget.localOwner ||
        service.recorder?.ownerId != widget.trip.ownerId) {
      return;
    }
    final trip = service.trips
        .where((trip) => trip.id == widget.trip.id)
        .firstOrNull;
    if (trip != null) {
      setState(() {
        _trip = trip;
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _clock?.cancel();
    service.removeListener(_localUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    final points = trip?.points ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(trip?.name ?? 'Track')),
      body: trip == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error ?? 'Track unavailable.'),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        breadcrumbStatus(
                          trip,
                          DateTime.now(),
                          connected: service.connected,
                        ),
                      ),
                      if (points.isNotEmpty)
                        Text('Last GPS fix: ${_date(points.last.time)}'),
                      if (widget.localOwner && service.error != null)
                        Text(service.error!),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() => _follow = false);
                              if (points.isNotEmpty) {
                                unawaited(
                                  _map?.fitBounds(
                                        points
                                            .map((point) => point.location)
                                            .toList(),
                                      ) ??
                                      Future.value(),
                                );
                              }
                            },
                            child: const Text('Show whole track'),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _follow = true),
                            child: const Text('Follow latest location'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: points.isEmpty
                      ? const Center(
                          child: Text('Waiting for recorded locations.'),
                        )
                      : GabayTrackMap(
                          initialCamera: CameraPosition(
                            target: points.first.location,
                            zoom: 16,
                          ),
                          routePoints: points
                              .map((point) => point.location)
                              .toList(),
                          markers: [
                            GabayMapMarkerData(
                              id: 'start',
                              position: points.first.location,
                              kind: GabayMapMarkerKind.routeStart,
                            ),
                            GabayMapMarkerData(
                              id: 'latest',
                              position: points.last.location,
                              kind: GabayMapMarkerKind.navigator,
                            ),
                          ],
                          padding: EdgeInsets.zero,
                          followTarget: points.last.location,
                          followUser: trip.isRecording && _follow,
                          onControllerReady: (map) {
                            _map = map;
                            if (!trip.isRecording) {
                              unawaited(
                                map.fitBounds(
                                  points
                                      .map((point) => point.location)
                                      .toList(),
                                ),
                              );
                            }
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
