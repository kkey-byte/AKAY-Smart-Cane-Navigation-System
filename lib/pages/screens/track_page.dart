import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/linked_navigator.dart';

import '../../models/route_plan.dart';

import '../../models/search_destination.dart';
import '../../services/destination_search_service.dart';
import '../../services/gabay_tts_service.dart';
import '../../services/map_place_service.dart';
import '../../services/app_session_service.dart';
import '../../models/dashboard_snapshot.dart';
import '../../services/dashboard_service.dart';
import '../../services/navigation_persistence_service.dart';
import '../../services/breadcrumb_service.dart';
import '../../widgets/track/breadcrumb_feature_card.dart';

import '../../services/route_timeline_tracker.dart';

import '../../services/navigator_location_service.dart';

import '../../services/vi_navigation_session.dart';

import '../../theme/gabay_theme.dart';
import '../../utils/gabay_map_rendering.dart';
import '../../widgets/shared/floating_bottom_nav_shell.dart';
import '../../widgets/shared/gabay_page_route.dart';

import '../../widgets/track/eta_card.dart';
import '../../widgets/track/gabay_map_marker.dart';
import '../../widgets/track/gabay_track_map.dart';

import '../../widgets/track/floating_route_button.dart';

import '../../widgets/track/map_zoom_controls.dart';

import '../../widgets/track/navigator_destination_panel.dart';

import '../../widgets/track/navigator_monitor_sheet.dart';

import '../../widgets/track/navigator_track_controls.dart';

import '../../widgets/track/turn_by_turn_panel.dart';

import 'route_planner_page.dart';

enum TrackPageRole { caregiver, navigator }

class TrackPage extends StatefulWidget {
  const TrackPage({super.key, this.role = TrackPageRole.caregiver});

  final TrackPageRole role;

  @override
  State<TrackPage> createState() => TrackPageState();
}

class TrackPageState extends State<TrackPage> {
  /// Read-only Home rendering of this screen's existing route and GPS state.
  /// It owns no navigation session, GPS subscription, or route calculation.
  Widget? buildHomeMapPreview() {
    final route = _activeRoute;
    if (route == null) return null;
    return ListenableBuilder(
      listenable: _locationService,
      builder: (context, _) => IgnorePointer(
        child: GabayTrackMap(
          key: ValueKey(route),
          initialCamera: _initialCamera,
          markers: _buildNavigatorMarkerData(),
          routePoints: route.polylinePoints,
          padding: EdgeInsets.zero,
          onControllerReady: (controller) {
            final points = [
              ...route.polylinePoints,
              if (_locationService.livePosition != null)
                _locationService.livePosition!,
              route.destination.latLng,
            ];
            unawaited(controller.fitBounds(points, padding: 36));
          },
        ),
      ),
    );
  }

  TrackMapController? _mapController;

  RoutePlanResult? _activeRoute;

  bool _isEtaPanelVisible = true;

  bool _isTurnByTurnVisible = true;

  bool _voiceGuidanceEnabled = true;

  late String _selectedNavigatorId;

  bool _showAllNavigatorsOnMap = true;

  /// Navigator-mode destination search (replaces coordinates / "Walking" panel).
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();
  List<MapPlace> _destinationSuggestions = [];
  bool _isSearchingDestination = false;
  int? _routeRequestToken;
  bool _isResolvingMapPin = false;
  bool _showSearchEmpty = false;
  bool _useWiderSearch = false;
  MapPlace? _pinnedDestination;

  int _destinationSearchToken = 0;

  /// Pause camera follow while the user is pinning / browsing the map.
  bool _followCamera = true;
  bool _centeredOnDevice = false;
  List<String> _recentSearchQueries = [];
  int _recentSearchGeneration = 0;
  Future<void> _recentSearchWrite = Future<void>.value();
  String? _selectedCategoryQuery;

  List<LinkedNavigator> _navigators = [];
  final _liveLocationSubscriptions = <StreamSubscription<DashboardSnapshot>>[];
  StreamSubscription<User?>? _caregiverAuth;
  StreamSubscription<Map<String, String>>? _caregiverLinks;
  final _patientLive = <String, DashboardSnapshot>{};
  Map<String, String> _patientNames = {};
  Timer? _freshnessTimer;
  int _patientGeneration = 0;
  String? _patientError;

  final _timelineTracker = RouteTimelineTracker.instance;

  final _locationService = NavigatorLocationService.instance;

  final _placeService = MapPlaceService.instance;

  final _destinationSearch = DestinationSearchService.instance;

  final _tts = GabayTtsService.instance;

  final _navPersistence = NavigationPersistenceService.instance;

  GabayMapMarkerIcons? _mapIcons;

  bool get _isNavigatorMode => widget.role == TrackPageRole.navigator;

  bool get _isNavigating => _activeRoute != null;

  CameraPosition get _initialCamera {
    // Prefer a real GPS fix; never bootstrap on the old Panabo mock pin.
    final live = _locationService.livePosition;
    final target = live ?? GabayMapDefaults.mapCenter;
    return CameraPosition(
      target: target,
      zoom: (live != null) ? 16 : GabayMapDefaults.defaultZoom,
    );
  }

  LinkedNavigator get _selectedNavigator {
    if (_isNavigatorMode) {
      final self = LinkedNavigatorService.selfNavigator;
      return LinkedNavigator(
        id: self.id,
        name: _sessionNavigatorFullName,
        address: _locationService.address.isNotEmpty
            ? _locationService.address
            : self.address,
        location: _locationService.livePosition ?? self.location,
        status: self.status,
        batteryPercent: self.batteryPercent,
        isOnline: self.isOnline,
      );
    }

    return _navigators
            .where((navigator) => navigator.id == _selectedNavigatorId)
            .firstOrNull ??
        LinkedNavigator(
          id: '',
          name: 'Monitor your patient',
          address:
              _patientError ?? 'Open Breadcrumb tracks to link a navigator.',
          location: GabayMapDefaults.mapCenter,
          status: 'No shared patient',
          batteryPercent: -1,
          isOnline: false,
        );
  }

  String get _sessionNavigatorFullName {
    final name = AppSessionService.instance.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = AppSessionService.instance.email?.trim();
    if (email != null && email.isNotEmpty) {
      final local = email.split('@').first.trim();
      if (local.isNotEmpty) return local;
    }
    return 'Navigator';
  }

  @override
  void initState() {
    super.initState();
    BreadcrumbService.instance.addListener(_onBreadcrumbUpdated);

    if (_isNavigatorMode) {
      _selectedNavigatorId = LinkedNavigatorService.selfNavigator.id;

      _showAllNavigatorsOnMap = false;
    } else {
      _selectedNavigatorId = '';
      _showAllNavigatorsOnMap = false;
    }

    _timelineTracker.addListener(_onTimelineUpdated);

    _locationService.addListener(_onLocationUpdated);
    unawaited(_bootstrapLiveLocation());
    if (_isNavigatorMode) {
      unawaited(_loadRecentSearches());
    } else {
      _watchCaregiverLocations();
    }

    _loadMapIcons();
  }

  void _watchCaregiverLocations() {
    _caregiverAuth = FirebaseAuth.instance.authStateChanges().listen((user) {
      unawaited(_caregiverLinks?.cancel());
      _replacePatients({});
      if (user == null) return;
      _caregiverLinks = BreadcrumbService.instance.repository
          .watchLinks(user.uid)
          .listen(
            _replacePatients,
            onError: (Object error) {
              _replacePatients({});
              if (mounted) {
                setState(
                  () => _patientError =
                      'Unable to load shared patients. Open Breadcrumb tracks to retry.',
                );
              }
            },
          );
    });
    _freshnessTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshPatientLocations(),
    );
  }

  void _replacePatients(Map<String, String> patients) {
    if (!mounted) return;
    if (patients.length == _patientNames.length &&
        patients.entries.every(
          (entry) => _patientNames[entry.key] == entry.value,
        )) {
      return;
    }
    _patientNames = Map.of(patients);
    final generation = ++_patientGeneration;
    for (final subscription in _liveLocationSubscriptions) {
      unawaited(subscription.cancel());
    }
    _liveLocationSubscriptions.clear();
    _patientLive.clear();
    _patientError = null;
    _navigators = patients.entries
        .map(
          (entry) => LinkedNavigator(
            id: entry.key,
            name: entry.value,
            address: 'No recorded location yet',
            location: GabayMapDefaults.mapCenter,
            status: 'Waiting for track',
            batteryPercent: -1,
            isOnline: false,
          ),
        )
        .toList();
    if (!patients.containsKey(_selectedNavigatorId)) {
      _selectedNavigatorId = patients.keys.firstOrNull ?? '';
    }
    if (_activeRoute != null &&
        !patients.containsKey(_activeRoute!.navigator.id)) {
      _activeRoute = null;
    }
    setState(() {});
    for (final owner in patients.keys) {
      _liveLocationSubscriptions.add(
        DashboardService.instance
            .watch(owner)
            .listen(
              (data) {
                if (!mounted || generation != _patientGeneration) return;
                final hadLocation = _patientLive[owner]?.position != null;
                if (data.uid != owner) {
                  _patientLive.remove(owner);
                } else {
                  _patientLive[owner] = data;
                }
                _refreshPatientLocations();
                if (!hadLocation &&
                    owner == _selectedNavigatorId &&
                    _selectedNavigator.lastLocationUpdated != null) {
                  unawaited(_focusOnNavigator(_selectedNavigator));
                }
              },
              onError: (Object error) {
                if (!mounted || generation != _patientGeneration) return;
                _patientLive.remove(owner);
                _patientError =
                    'Track unavailable. Check connection or sharing access.';
                _refreshPatientLocations();
              },
            ),
      );
    }
  }

  void _refreshPatientLocations() {
    if (!mounted || _isNavigatorMode) return;
    final now = DateTime.now();
    setState(() {
      _navigators = _navigators.map((navigator) {
        final data = _patientLive[navigator.id];
        final position = data?.position;
        return navigator.copyWith(
          location: position ?? GabayMapDefaults.mapCenter,
          address: position == null
              ? (_patientError ?? 'Waiting for shared GPS location')
              : '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
          status: data?.trackingLabel(now) ?? 'Location unavailable',
          isOnline: position != null && (data?.fresh(now) ?? false),
          lastLocationUpdated: position == null ? null : data?.locationTime,
          replaceLastLocationUpdated: true,
        );
      }).toList();
    });
  }

  Future<void> _loadRecentSearches() async {
    final generation = _recentSearchGeneration;
    final recent = await _destinationSearch.loadRecentQueries();
    if (!mounted || generation != _recentSearchGeneration) return;
    setState(() => _recentSearchQueries = recent);
  }

  Future<void> _bootstrapLiveLocation() async {
    await _locationService.startTracking();
    if (!mounted) return;

    if (_locationService.permissionDenied) {
      _showSnack(
        _locationService.errorMessage ?? 'Location permission denied.',
      );
      return;
    }

    if (_locationService.errorMessage != null && !_locationService.hasLiveFix) {
      _showSnack(_locationService.errorMessage!);
    }

    _centerOnDeviceOnce();
  }

  void _onLocationUpdated() {
    if (!mounted) return;
    setState(() {});
    _centerOnDeviceOnce();
    // Camera follow is handled by GabayTrackMap via [followTarget].
    // Stream live GPS to Firebase RTDB + sync distance to Postgres.
    if (_isNavigatorMode && _isNavigating) {
      final live = _locationService.livePosition;
      if (live != null) {
        unawaited(_navPersistence.publishLiveLocation(live));
      }
    }
  }

  void _onBreadcrumbUpdated() {
    if (!_isNavigatorMode) {
      _refreshPatientLocations();
      return;
    }
    if (mounted) setState(() {});
  }

  void _centerOnDeviceOnce() {
    final live = _locationService.livePosition;
    if (_centeredOnDevice || live == null || _mapController == null) return;
    _centeredOnDevice = true;
    unawaited(_mapController!.animateToLatLng(live, zoom: 16));
  }

  Future<void> _persistNavigationStart(RoutePlanResult result) async {
    if (!_isNavigatorMode) return;
    final origin = _locationService.livePosition ?? result.navigator.location;
    await _navPersistence.startSession(
      origin: origin,
      destination: result.destination,
      originAddress: _locationService.address,
    );
  }

  Future<void> _loadMapIcons() async {
    final icons = await GabayMapRendering.loadMarkerIcons();

    if (!mounted) return;

    setState(() => _mapIcons = icons);
  }

  void _onTimelineUpdated() {
    if (!mounted) return;
    if (!_timelineTracker.isTracking &&
        _timelineTracker.entries.isNotEmpty &&
        _timelineTracker.entries.last.isArrived) {
      if (_isNavigatorMode) {
        if (_navPersistence.hasActiveSession) {
          unawaited(_navPersistence.endSession());
        }
        ViNavigationSession.instance.setNavigating(false);
      }
      _clearMapRecentSearches();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _patientGeneration++;
    unawaited(_caregiverAuth?.cancel());
    unawaited(_caregiverLinks?.cancel());
    _freshnessTimer?.cancel();
    BreadcrumbService.instance.removeListener(_onBreadcrumbUpdated);

    _timelineTracker.removeListener(_onTimelineUpdated);

    _locationService.removeListener(_onLocationUpdated);
    if (_isNavigatorMode && !BreadcrumbService.instance.trackingRequested) {
      _locationService.stopTracking();
    }
    for (final subscription in _liveLocationSubscriptions) {
      unawaited(subscription.cancel());
    }

    unawaited(_tts.stop());
    _destinationController.dispose();
    _destinationFocusNode.dispose();

    super.dispose();
  }

  void _onDestinationQueryChanged(String query) {
    if (!_isNavigatorMode || _isNavigating) return;

    _destinationSearchToken++;
    setState(() {
      _destinationSuggestions = [];
      _pinnedDestination = null;
      _isResolvingMapPin = false;
      _isSearchingDestination = false;
      _showSearchEmpty = false;
      _useWiderSearch = false;
    });
  }

  Future<void> _runNearbyDestinationSearch(
    String query, {
    bool wider = false,
  }) async {
    final token = ++_destinationSearchToken;
    final near = _locationService.livePosition;

    setState(() {
      _isSearchingDestination = true;
      _isResolvingMapPin = false;
      _pinnedDestination = null;
    });
    try {
      final results = await _destinationSearch.search(
        query: query,
        near: near,
        radiusMeters: 5000,
        wider: wider,
      );

      if (!mounted || token != _destinationSearchToken) return;
      setState(() {
        _destinationSuggestions = results.map((e) => e.toMapPlace()).toList();
        _isSearchingDestination = false;
        _showSearchEmpty = results.isEmpty;
        _useWiderSearch = wider;
      });

      if (results.isNotEmpty) {
        final generation = _recentSearchGeneration;
        await (_recentSearchWrite = _recentSearchWrite.then(
          (_) => _destinationSearch.saveRecentQuery(query),
        ));
        if (!mounted || generation != _recentSearchGeneration) return;
        await _loadRecentSearches();
      }
    } catch (_) {
      if (!mounted || token != _destinationSearchToken) return;
      setState(() {
        _isSearchingDestination = false;
        _showSearchEmpty = false;
        _destinationSuggestions = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Search unavailable. Check your connection and retry.'),
        ),
      );
    }
  }

  void _onCategorySelected(SearchCategory category) {
    if (_isNavigating) return;
    _destinationController.text = category.label;
    setState(() {
      _selectedCategoryQuery = category.query;
      _isSearchingDestination = true;
      _showSearchEmpty = false;
    });
    unawaited(_runNearbyDestinationSearch(category.query));
  }

  void _onRecentSelected(String query) {
    _destinationController.text = query;
    setState(() {
      _selectedCategoryQuery = null;
      _isSearchingDestination = true;
      _showSearchEmpty = false;
    });
    unawaited(_runNearbyDestinationSearch(query));
  }

  Future<void> _speakPlace(MapPlace place) async {
    final dest = SearchDestination.fromMapPlace(place);
    await _tts.speak(dest.speakText);
  }

  void _onVoiceSearchTap() {
    _showSnack('Voice search will be available in a future update.');
  }

  Future<void> _selectDestinationPlace(MapPlace place) async {
    if (!place.hasValidCoordinates) {
      _showSnack(
        'This destination has invalid coordinates. Select another place or pin.',
      );
      return;
    }
    if (_routeRequestToken == _destinationSearchToken &&
        _pinnedDestination?.latitude == place.latitude &&
        _pinnedDestination?.longitude == place.longitude) {
      return;
    }
    final token = ++_destinationSearchToken;
    _routeRequestToken = token;
    _destinationFocusNode.unfocus();
    _destinationController.text = place.name;

    setState(() {
      _isSearchingDestination = true;
      _isResolvingMapPin = false;
      _destinationSuggestions = [];
      _pinnedDestination = place;
      _followCamera = true;
    });

    try {
      var live = _locationService.livePosition;
      if (live == null) {
        _showSnack('Fetching your current location...');
        await _locationService.refreshCurrentLocation();
        if (!mounted || token != _destinationSearchToken) return;
        live = _locationService.livePosition;
        if (live == null) {
          _showSnack(
            _locationService.errorMessage ??
                'Current location is unavailable. Allow location access, then retry this destination.',
          );
          return;
        }
      }

      // Use the live GPS fix as route origin (not any hardcoded city).
      final liveSelf = LinkedNavigator(
        id: LinkedNavigatorService.selfNavigator.id,
        name: _sessionNavigatorFullName,
        address: _locationService.address,
        location: live,
        status: 'Navigating',
        batteryPercent: LinkedNavigatorService.selfNavigator.batteryPercent,
        isOnline: true,
      );

      final result = await _placeService.buildRoutePlan(
        navigator: liveSelf,
        destination: place,
      );

      if (!mounted || token != _destinationSearchToken) return;

      setState(() {
        _activeRoute = result;
        _isEtaPanelVisible = true;
        _isTurnByTurnVisible = true;
        _selectedNavigatorId = result.navigator.id;
        _isSearchingDestination = false;
      });

      ViNavigationSession.instance.setNavigating(
        true,
        destination: _activeRoute?.destination.name,
        estimatedTime: _activeRoute?.estimatedTime,
        estimatedDistance: _activeRoute?.estimatedDistance,
      );
      _timelineTracker.startTracking(result.destination);
      await _persistNavigationStart(result);
      await _fitRouteOnMap(result);
      if (mounted && token == _destinationSearchToken) {
        _showSnack('Navigating to ${place.name}');
      }
    } catch (e) {
      if (!mounted || token != _destinationSearchToken) return;
      _showSnack(
        e is NavigationRouteException
            ? e.message
            : 'Could not start navigation. Please retry this destination.',
      );
    } finally {
      if (_routeRequestToken == token) _routeRequestToken = null;
      if (mounted && token == _destinationSearchToken) {
        setState(() => _isSearchingDestination = false);
      }
    }
  }

  Future<void> _submitDestinationSearch() async {
    final query = _destinationController.text.trim();
    if (query.isEmpty) {
      await _openRoutePlanner();
      return;
    }

    // Prefer an already-pinned map destination when the user taps search.
    final pin = _pinnedDestination;
    if (pin != null && pin.name.toLowerCase() == query.toLowerCase()) {
      await _selectDestinationPlace(pin);
      return;
    }

    await _runNearbyDestinationSearch(query, wider: _useWiderSearch);
  }

  Future<void> _onMapPinDestination(LatLng point) async {
    if (!_isNavigatorMode || _isNavigating) return;
    final token = ++_destinationSearchToken;

    setState(() {
      _isResolvingMapPin = true;
      _isSearchingDestination = false;
      _followCamera = false;
      _destinationSuggestions = [];
    });

    try {
      final place = await _placeService.placeFromCoordinates(point);
      if (!mounted || token != _destinationSearchToken) return;

      setState(() {
        _pinnedDestination = place;
        _destinationController.text = place.name;
        _isResolvingMapPin = false;
      });

      // Camera availability must not block coordinate-based routing.
      try {
        await _mapController?.animateToLatLng(point, zoom: 16);
      } catch (_) {}
      if (!mounted || token != _destinationSearchToken) return;
      // Pinning confirms the destination — start the route from current GPS.
      await _selectDestinationPlace(place);
    } catch (_) {
      if (!mounted || token != _destinationSearchToken) return;
      setState(() => _isResolvingMapPin = false);
      _showSnack('Could not resolve that pin. Try again.');
    }
  }

  String get _displayAddress {
    if (_isNavigatorMode) {
      if (_locationService.isLoading && !_locationService.hasLiveFix) {
        return 'Fetching current location...';
      }
      return _locationService.address;
    }

    return _selectedNavigator.address;
  }

  LatLng get _liveNavigatorPosition {
    if (_isNavigatorMode) {
      // Only use a real GPS fix — never the hardcoded Panabo mock.
      return _locationService.livePosition ?? GabayMapDefaults.mapCenter;
    }
    return _selectedNavigator.location;
  }

  LatLng? get _followTarget {
    if (!_followCamera) return null;
    if (!_isNavigatorMode) {
      return !_showAllNavigatorsOnMap &&
              _selectedNavigator.lastLocationUpdated != null
          ? _selectedNavigator.location
          : null;
    }
    return _locationService.livePosition;
  }

  Future<void> _openNavigatorMonitor() async {
    if (_navigators.isEmpty) {
      openBreadcrumbHistory(context, caregiver: true);
      return;
    }

    await NavigatorMonitorSheet.show(
      context,

      navigators: _navigators,

      selectedId: _selectedNavigatorId,

      showAllOnMap: _showAllNavigatorsOnMap,

      onNavigatorSelected: (navigator) {
        setState(() => _selectedNavigatorId = navigator.id);

        _focusOnNavigator(navigator);
      },

      onShowAllChanged: (value) {
        setState(() => _showAllNavigatorsOnMap = value);

        if (!value) {
          _focusOnNavigator(_selectedNavigator);
        } else {
          _fitAllNavigatorsOnMap();
        }
      },
    );
  }

  Future<void> _focusOnNavigator(LinkedNavigator navigator) async {
    if (!_isNavigatorMode && navigator.lastLocationUpdated == null) return;

    final target = _isNavigatorMode
        ? _liveNavigatorPosition
        : navigator.location;

    await _mapController?.animateToLatLng(target, zoom: 15);
  }

  Future<void> _fitAllNavigatorsOnMap() async {
    if (_mapController == null) return;

    final points = _navigators
        .where((navigator) => navigator.lastLocationUpdated != null)
        .map((navigator) => navigator.location)
        .toList();
    final deviceLocation = _locationService.livePosition;
    if (deviceLocation != null) points.add(deviceLocation);

    await _mapController!.fitBounds(points, padding: 80);
  }

  Future<void> _openRoutePlanner() async {
    if (!_isNavigatorMode && _selectedNavigator.lastLocationUpdated == null) {
      _showSnack(
        'Select a shared patient with a recorded location to plan a route.',
      );
      return;
    }

    final result = await context.pushGabayPage<RoutePlanResult>(
      RoutePlannerPage(
        initialNavigatorId: _activeRoute?.navigator.id ?? _selectedNavigatorId,
        linkedNavigators: _isNavigatorMode
            ? null
            : _navigators
                  .where((navigator) => navigator.lastLocationUpdated != null)
                  .toList(),
        isNavigatorMode: _isNavigatorMode,
      ),
    );

    if (!mounted || result == null) return;

    final stamped = _isNavigatorMode
        ? RoutePlanResult(
            navigator: LinkedNavigator(
              id: result.navigator.id,
              name: _sessionNavigatorFullName,
              address: result.navigator.address,
              location: result.navigator.location,
              status: result.navigator.status,
              batteryPercent: result.navigator.batteryPercent,
              isOnline: result.navigator.isOnline,
            ),
            destination: result.destination,
            estimatedTime: result.estimatedTime,
            estimatedDistance: result.estimatedDistance,
            currentSpeed: result.currentSpeed,
            navigationStatus: result.navigationStatus,
            polylinePoints: result.polylinePoints,
            tripStartedAt: result.tripStartedAt,
            turnInstructions: result.turnInstructions,
          )
        : result;

    setState(() {
      _activeRoute = stamped;
      _isEtaPanelVisible = true;
      _isTurnByTurnVisible = true;
      _selectedNavigatorId = stamped.navigator.id;
    });

    if (_isNavigatorMode) {
      ViNavigationSession.instance.setNavigating(
        true,
        destination: _activeRoute?.destination.name,
        estimatedTime: _activeRoute?.estimatedTime,
        estimatedDistance: _activeRoute?.estimatedDistance,
      );

      await _persistNavigationStart(result);

      if (mounted) {
        _showSnack(
          'Navigation started. Track sharing status is available in My tracks.',
        );
      }
    }

    _timelineTracker.startTracking(result.destination);

    await _fitRouteOnMap(result);
  }

  void _collapseEtaPanel() {
    setState(() => _isEtaPanelVisible = false);
  }

  void _clearMapRecentSearches() {
    _recentSearchGeneration++;
    _destinationSearchToken++;
    _recentSearchQueries = [];
    _isSearchingDestination = false;
    _showSearchEmpty = false;
    _recentSearchWrite = _recentSearchWrite.then(
      (_) => _destinationSearch.clearRecentQueries(),
    );
    unawaited(_recentSearchWrite);
  }

  Future<void> _cancelDestination() async {
    _clearMapRecentSearches();
    setState(() {
      _activeRoute = null;

      _isEtaPanelVisible = true;

      _pinnedDestination = null;

      _followCamera = true;

      _destinationController.clear();

      _destinationSuggestions = [];
    });

    if (_isNavigatorMode) {
      ViNavigationSession.instance.setNavigating(false);

      unawaited(_navPersistence.endSession(cancelled: true));
    }

    _timelineTracker.reset();

    if (_isNavigatorMode) {
      await _focusOnNavigator(_selectedNavigator);

      return;
    }

    if (_showAllNavigatorsOnMap) {
      await _fitAllNavigatorsOnMap();
    } else {
      await _focusOnNavigator(_selectedNavigator);
    }
  }

  Future<void> _fitRouteOnMap(RoutePlanResult route) async {
    if (_mapController == null || route.polylinePoints.isEmpty) return;

    await _mapController!.fitBounds(route.polylinePoints, padding: 80);
  }

  double _markerHueForIndex(int index, bool isSelected) {
    if (isSelected) return BitmapDescriptor.hueGreen;

    const hues = [
      BitmapDescriptor.hueOrange,

      BitmapDescriptor.hueViolet,

      BitmapDescriptor.hueRose,

      BitmapDescriptor.hueYellow,
    ];

    return hues[index % hues.length];
  }

  List<GabayMapMarkerData> _buildMarkerData() {
    if (_isNavigatorMode) {
      return _buildNavigatorMarkerData();
    }

    final markers = <GabayMapMarkerData>[
      if (_locationService.livePosition != null)
        GabayMapMarkerData(
          id: 'caregiver',

          position: _locationService.livePosition!,

          kind: GabayMapMarkerKind.caregiver,

          title: 'Your current location',

          snippet: _locationService.address,
        ),
    ];

    for (var i = 0; i < _navigators.length; i++) {
      final navigator = _navigators[i];
      if (navigator.lastLocationUpdated == null) continue;

      final isSelected = navigator.id == _selectedNavigatorId;

      final showMarker = _showAllNavigatorsOnMap || isSelected;

      if (!showMarker) continue;

      markers.add(
        GabayMapMarkerData(
          id: 'navigator_${navigator.id}',

          position: navigator.location,

          kind: isSelected
              ? GabayMapMarkerKind.navigator
              : GabayMapMarkerKind.generic,

          zIndex: isSelected ? 2 : 1,

          title: navigator.name,

          snippet: '${navigator.status} • ${navigator.address}',

          hue: _markerHueForIndex(i, isSelected),
        ),
      );
    }

    if (_activeRoute != null) {
      _addActiveRouteMarkerData(
        markers,

        route: _activeRoute!,

        progressLocation: _liveNavigatorPosition,
      );
    }

    return markers;
  }

  List<GabayMapMarkerData> _buildNavigatorMarkerData() {
    final markers = <GabayMapMarkerData>[];

    if (_activeRoute == null) {
      final live = _locationService.livePosition;
      if (live != null) {
        markers.add(
          GabayMapMarkerData(
            id: 'self',
            position: live,
            kind: GabayMapMarkerKind.navigator,
            title: 'Your location',
            snippet: _displayAddress,
          ),
        );
      }

      final pin = _pinnedDestination;
      if (pin != null) {
        markers.add(
          GabayMapMarkerData(
            id: 'pinned_destination',
            position: pin.latLng,
            kind: GabayMapMarkerKind.destination,
            zIndex: 4,
            title: pin.name,
            snippet: pin.distance == null
                ? pin.address
                : '${pin.distance} • ${pin.address}',
          ),
        );
      }
    } else {
      _addActiveRouteMarkerData(
        markers,

        route: _activeRoute!,

        progressLocation: _liveNavigatorPosition,
      );
    }

    return markers;
  }

  void _addActiveRouteMarkerData(
    List<GabayMapMarkerData> markers, {

    required RoutePlanResult route,

    required LatLng progressLocation,
  }) {
    final points = route.polylinePoints;

    final destination = route.destination;

    if (points.isNotEmpty) {
      markers.add(
        GabayMapMarkerData(
          id: 'route_start',

          position: points.first,

          kind: GabayMapMarkerKind.routeStart,

          zIndex: 3,

          title: 'Route start',

          snippet: 'Navigation started here',
        ),
      );
    }

    markers.add(
      GabayMapMarkerData(
        id: 'route_progress',

        position: progressLocation,

        kind: GabayMapMarkerKind.routeProgress,

        zIndex: 5,

        title: 'Current position',

        snippet: 'On route',
      ),
    );

    markers.add(
      GabayMapMarkerData(
        id: 'destination',

        position: destination.latLng,

        kind: GabayMapMarkerKind.destination,

        zIndex: 4,

        title: destination.name,

        snippet: destination.address,
      ),
    );
  }

  Future<void> _zoomIn() async {
    await _mapController?.zoomIn();
  }

  Future<void> _zoomOut() async {
    await _mapController?.zoomOut();
  }

  static const _mapControlGap = 12.0;
  static const _destinationControlSize = 52.0;
  static const _voiceControlSize = 52.0;

  double _leftMapControlsHeight() {
    if (!_isNavigating) return 0;
    if (_isNavigatorMode) {
      return _voiceControlSize + _mapControlGap + _destinationControlSize;
    }
    if (!_isEtaPanelVisible) return _destinationControlSize;
    return 0;
  }

  double _zoomControlsBottom(BuildContext context) {
    final navInset = GabayNavMetrics.overlayBottom(context);
    if (!_isNavigating) return navInset + 72;

    final leftHeight = _leftMapControlsHeight();
    if (leftHeight <= 0) return navInset + 16;

    return navInset;
  }

  double _mapBottomPadding(BuildContext context) {
    final navInset = GabayNavMetrics.overlayBottom(context);

    if (!_isNavigating) return navInset;

    if (_isEtaPanelVisible) return navInset + 360;

    return navInset;
  }

  double _mapTopPadding(BuildContext context) {
    var top = MediaQuery.of(context).padding.top + 84;
    if (!_isNavigatorMode) top += 100;

    if (_isNavigatorMode && _isNavigating) {
      top += 10;

      if (_isTurnByTurnVisible) {
        top += 172;
      } else {
        top += 52;
      }
    }

    return top;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedNavigator;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      body: Stack(
        children: [
          Positioned.fill(
            child: GabayTrackMap(
              initialCamera: _initialCamera,
              markers: _buildMarkerData(),
              routePoints: _activeRoute?.polylinePoints ?? const [],
              breadcrumbPoints: _isNavigatorMode
                  ? BreadcrumbService.instance.points
                        .map((point) => point.location)
                        .toList()
                  : _patientLive[_selectedNavigatorId]?.points ?? const [],
              googleMarkerIcons: _mapIcons,
              followUser:
                  (_isNavigatorMode || !_showAllNavigatorsOnMap) &&
                  _followCamera,
              followTarget: _followTarget,
              followZoom: 16,
              onMapTap: _isNavigatorMode && !_isNavigating
                  ? (point) => unawaited(_onMapPinDestination(point))
                  : null,
              padding: EdgeInsets.only(
                top: _mapTopPadding(context),
                bottom: _mapBottomPadding(context),
                right: 8,
              ),
              onControllerReady: (controller) {
                _mapController = controller;
                if (_isNavigatorMode) {
                  final live = _locationService.livePosition;
                  if (live != null) {
                    unawaited(controller.animateToLatLng(live, zoom: 16));
                  }
                }
                _centerOnDeviceOnce();
              },
            ),
          ),

          // Locating overlay — map tiles still visible underneath.
          if (_isNavigatorMode && !_locationService.hasLiveFix)
            Positioned(
              left: 16,
              right: 16,
              bottom: GabayNavMetrics.overlayBottom(context) + 72,
              child: Material(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.94),
                elevation: 3,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: context.gabay.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _locationService.errorMessage ??
                              'Detecting your exact GPS location…',
                          style: TextStyle(
                            color: context.gabay.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => unawaited(
                          _locationService.refreshCurrentLocation(),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 12,

            left: 16,

            right: 16,

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,

              mainAxisSize: MainAxisSize.min,

              children: [
                if (_isNavigatorMode)
                  NavigatorDestinationPanel(
                    controller: _destinationController,
                    focusNode: _destinationFocusNode,
                    suggestions: _destinationSuggestions,
                    isNavigating: _isNavigating,
                    isSearching: _isSearchingDestination,
                    activeDestinationName: _activeRoute?.destination.name,
                    onChanged: _onDestinationQueryChanged,
                    onSubmitted: (_) => _submitDestinationSearch(),
                    onSearchTap: _submitDestinationSearch,
                    onSuggestionTap: _selectDestinationPlace,
                    onClear: () {
                      _destinationSearchToken++;
                      _destinationController.clear();
                      setState(() {
                        _destinationSuggestions = [];
                        _isSearchingDestination = false;
                        _isResolvingMapPin = false;
                        _pinnedDestination = null;
                        _showSearchEmpty = false;
                        _selectedCategoryQuery = null;
                        _useWiderSearch = false;
                      });
                    },
                    onCancelNavigation: _isNavigating
                        ? _cancelDestination
                        : null,
                    showPinHint: !_isNavigating && _pinnedDestination == null,
                    isResolvingPin: _isResolvingMapPin,
                    categories: SearchCategory.all,
                    onCategorySelected: _onCategorySelected,
                    recentQueries: _recentSearchQueries,
                    onRecentSelected: _onRecentSelected,
                    onSpeakPlace: (place) => unawaited(_speakPlace(place)),
                    onNavigatePlace: _selectDestinationPlace,
                    showEmptyState: _showSearchEmpty,
                    onSearchWider: () {
                      final q = _destinationController.text.trim();
                      if (q.isEmpty) return;
                      setState(() {
                        _isSearchingDestination = true;
                        _showSearchEmpty = false;
                        _useWiderSearch = true;
                      });
                      unawaited(_runNearbyDestinationSearch(q, wider: true));
                    },
                    onVoiceSearch: _onVoiceSearchTap,
                    selectedCategoryQuery: _selectedCategoryQuery,
                  )
                else
                  _CurrentAddressCard(
                    navigatorName: selected.name,
                    showNavigatorName: true,
                    address: _displayAddress,
                    status: selected.status,
                    isLive: selected.isOnline,
                    lastLocationUpdated: selected.lastLocationUpdated,
                    onTap: _openNavigatorMonitor,
                  ),
                if (!_isNavigatorMode) ...[
                  const SizedBox(height: 8),
                  const BreadcrumbFeatureCard(caregiver: true, compact: true),
                ],

                if (_isNavigatorMode && _isNavigating) ...[
                  const SizedBox(height: 10),

                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 280),

                    crossFadeState: _isTurnByTurnVisible
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,

                    sizeCurve: Curves.easeOutCubic,

                    firstChild: TurnByTurnPanel(
                      steps: turnStepsFromRoute(_activeRoute),
                      onClose: () =>
                          setState(() => _isTurnByTurnVisible = false),
                    ),

                    secondChild: Align(
                      alignment: Alignment.centerRight,

                      child: OpenTurnByTurnButton(
                        onPressed: () =>
                            setState(() => _isTurnByTurnVisible = true),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (_isNavigating && (_isNavigatorMode || !_isEtaPanelVisible))
            Positioned(
              left: 16,

              bottom: GabayNavMetrics.overlayBottom(context),

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  if (_isNavigatorMode) ...[
                    VoiceGuidanceButton(
                      enabled: _voiceGuidanceEnabled,

                      onPressed: () {
                        setState(
                          () => _voiceGuidanceEnabled = !_voiceGuidanceEnabled,
                        );

                        _showSnack(
                          _voiceGuidanceEnabled
                              ? 'Voice guidance enabled'
                              : 'Voice guidance disabled',
                        );
                      },
                    ),

                    const SizedBox(height: _mapControlGap),
                  ],

                  if (!_isEtaPanelVisible)
                    TweenAnimationBuilder<double>(
                      key: const ValueKey('reopen_eta'),

                      tween: Tween(begin: 0, end: 1),

                      duration: const Duration(milliseconds: 300),

                      curve: Curves.easeOutBack,

                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,

                          child: Opacity(opacity: value, child: child),
                        );
                      },

                      child: ReopenEtaButton(
                        onPressed: () =>
                            setState(() => _isEtaPanelVisible = true),
                      ),
                    )
                  else if (_isNavigatorMode)
                    const SizedBox(
                      width: _destinationControlSize,

                      height: _destinationControlSize,
                    ),
                ],
              ),
            ),

          Positioned(
            right: 16,

            bottom: _zoomControlsBottom(context),

            child: MapZoomControls(onZoomIn: _zoomIn, onZoomOut: _zoomOut),
          ),

          if (_isNavigating)
            Positioned(
              left: 16,

              right: 16,

              bottom: GabayNavMetrics.overlayBottom(context),

              child: AnimatedSlide(
                offset: _isEtaPanelVisible ? Offset.zero : const Offset(0, 1.2),

                duration: const Duration(milliseconds: 320),

                curve: Curves.easeOutCubic,

                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 280),

                  opacity: _isEtaPanelVisible ? 1 : 0,

                  child: IgnorePointer(
                    ignoring: !_isEtaPanelVisible,

                    child: EtaCard(
                      route: _activeRoute!,

                      timelineEntries: _timelineTracker.entries,

                      currentLocationAddress: _displayAddress,

                      onDragDismiss: _collapseEtaPanel,

                      onCancelDestination: _cancelDestination,
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            right: 16,

            bottom: GabayNavMetrics.overlayBottom(context),

            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 280),

              opacity: _isNavigating ? 0 : 1,

              child: IgnorePointer(
                ignoring: _isNavigating,

                child: AnimatedScale(
                  duration: const Duration(milliseconds: 280),

                  scale: _isNavigating ? 0.8 : 1,

                  curve: Curves.easeOutCubic,

                  child: FloatingRouteButton(onPressed: _openRoutePlanner),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentAddressCard extends StatelessWidget {
  final String navigatorName;

  final bool showNavigatorName;

  final String address;

  final String status;

  final bool isLive;

  final DateTime? lastLocationUpdated;

  final VoidCallback? onTap;

  const _CurrentAddressCard({
    required this.navigatorName,

    this.showNavigatorName = true,

    required this.address,

    required this.status,

    required this.isLive,

    this.lastLocationUpdated,

    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Material(
      color: g.surface,

      elevation: 4,

      shadowColor: g.shadow,

      borderRadius: BorderRadius.circular(18),

      child: InkWell(
        borderRadius: BorderRadius.circular(18),

        onTap: onTap,

        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

          child: Row(
            children: [
              Container(
                width: 40,

                height: 40,

                decoration: BoxDecoration(
                  color: g.accentTint,

                  borderRadius: BorderRadius.circular(12),
                ),

                child: Icon(
                  showNavigatorName
                      ? Icons.person_pin_circle_rounded
                      : Icons.my_location_rounded,

                  color: g.accent,

                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    if (showNavigatorName) ...[
                      Text(
                        navigatorName,

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: GabayTheme.bodyLarge(
                          context,
                        ).copyWith(fontSize: 15),
                      ),

                      const SizedBox(height: 2),
                    ],

                    Text(
                      address,

                      maxLines: showNavigatorName ? 1 : 2,

                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        fontSize: showNavigatorName ? 13 : 16,

                        fontWeight: showNavigatorName
                            ? FontWeight.w500
                            : FontWeight.w700,

                        color: showNavigatorName
                            ? g.textSecondary
                            : g.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      status,

                      style: TextStyle(
                        fontSize: 12,

                        fontWeight: FontWeight.w600,

                        color: isLive ? g.success : g.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      _lastUpdatedLabel(lastLocationUpdated),

                      style: TextStyle(
                        fontSize: 12,

                        fontWeight: FontWeight.w500,

                        color: g.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),

                  decoration: BoxDecoration(
                    color: g.success.withValues(alpha: 0.15),

                    borderRadius: BorderRadius.circular(20),
                  ),

                  child: Text(
                    'LIVE',

                    style: TextStyle(
                      color: g.success,

                      fontWeight: FontWeight.w800,

                      fontSize: 11,
                    ),
                  ),
                ),

              if (onTap != null) ...[
                const SizedBox(width: 4),

                Icon(Icons.keyboard_arrow_down_rounded, color: g.textSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _lastUpdatedLabel(DateTime? timestamp) {
    if (timestamp == null) return 'Location update unavailable';

    final local = timestamp.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return 'Last updated: $hour:$minute $period';
  }
}
