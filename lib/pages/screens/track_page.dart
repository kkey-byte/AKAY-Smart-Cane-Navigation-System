import 'dart:async';

import 'package:flutter/material.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';



import '../../models/linked_navigator.dart';

import '../../models/route_plan.dart';

import '../../models/search_destination.dart';
import '../../services/destination_search_service.dart';
import '../../services/gabay_tts_service.dart';
import '../../services/map_place_service.dart';
import '../../services/app_session_service.dart';
import '../../services/navigation_persistence_service.dart';

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

  State<TrackPage> createState() => _TrackPageState();

}



class _TrackPageState extends State<TrackPage> {

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
  bool _isResolvingMapPin = false;
  bool _showSearchEmpty = false;
  bool _useWiderSearch = false;
  MapPlace? _pinnedDestination;
  Timer? _destinationSearchDebounce;
  int _destinationSearchToken = 0;
  /// Pause camera follow while the user is pinning / browsing the map.
  bool _followCamera = true;
  List<String> _recentSearchQueries = [];
  String? _selectedCategoryQuery;



  final _navigators = LinkedNavigatorService.navigators;

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
      zoom: (_isNavigatorMode && live != null)
          ? 16
          : GabayMapDefaults.defaultZoom,
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

    return LinkedNavigatorService.instance.findById(_selectedNavigatorId) ??
        _navigators.first;
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

    if (_isNavigatorMode) {

      _selectedNavigatorId = LinkedNavigatorService.selfNavigator.id;

      _showAllNavigatorsOnMap = false;

    } else {

      _selectedNavigatorId = _navigators.first.id;

    }

    _timelineTracker.addListener(_onTimelineUpdated);

    if (_isNavigatorMode) {
      _locationService.addListener(_onLocationUpdated);
      unawaited(_bootstrapLiveLocation());
      unawaited(_loadRecentSearches());
    }

    _loadMapIcons();

  }

  Future<void> _loadRecentSearches() async {
    final recent = await _destinationSearch.loadRecentQueries();
    if (!mounted) return;
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

    if (_locationService.errorMessage != null &&
        !_locationService.hasLiveFix) {
      _showSnack(_locationService.errorMessage!);
    }

    // Force a second high-accuracy reading shortly after open.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await _locationService.refreshCurrentLocation();
  }

  void _onLocationUpdated() {
    if (!mounted) return;
    setState(() {});
    // Camera follow is handled by GabayTrackMap via [followTarget].
    // Stream live GPS to Firebase RTDB + sync distance to Postgres.
    if (_isNavigatorMode && _isNavigating) {
      final live = _locationService.livePosition;
      if (live != null) {
        unawaited(_navPersistence.publishLiveLocation(live));
      }
    }
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

    if (mounted) setState(() {});

  }



  @override

  void dispose() {

    _timelineTracker.removeListener(_onTimelineUpdated);

    if (_isNavigatorMode) {
      _locationService.removeListener(_onLocationUpdated);
      _locationService.stopTracking();
    }

    _destinationSearchDebounce?.cancel();
    unawaited(_tts.stop());
    _destinationController.dispose();
    _destinationFocusNode.dispose();

    super.dispose();

  }

  void _onDestinationQueryChanged(String query) {
    if (!_isNavigatorMode || _isNavigating) return;

    _destinationSearchDebounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _destinationSuggestions = [];
        _isSearchingDestination = false;
        _showSearchEmpty = false;
        _selectedCategoryQuery = null;
        _useWiderSearch = false;
      });
      return;
    }

    setState(() {
      _isSearchingDestination = true;
      _showSearchEmpty = false;
      _useWiderSearch = false;
    });
    _destinationSearchDebounce = Timer(const Duration(milliseconds: 380), () {
      unawaited(_runNearbyDestinationSearch(trimmed));
    });
  }

  Future<void> _runNearbyDestinationSearch(
    String query, {
    bool wider = false,
  }) async {
    final token = ++_destinationSearchToken;
    final near = _locationService.livePosition;

    final results = await _destinationSearch.search(
      query: query,
      near: near,
      radiusMeters: wider ? 15000 : 5000,
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
      await _destinationSearch.saveRecentQuery(query);
      await _loadRecentSearches();
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
    _destinationFocusNode.unfocus();
    _destinationController.text = place.name;

    setState(() {
      _isSearchingDestination = true;
      _destinationSuggestions = [];
      _pinnedDestination = place;
      _followCamera = true;
    });

    try {
      final live = _locationService.livePosition;
      if (live == null) {
        _showSnack('Still locating you. Please wait for GPS, then try again.');
        setState(() => _isSearchingDestination = false);
        await _locationService.refreshCurrentLocation();
        return;
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

      if (!mounted) return;

      final usedRoadRoute = result.polylinePoints.length > 2;

      setState(() {
        _activeRoute = result;
        _isEtaPanelVisible = true;
        _isTurnByTurnVisible = true;
        _selectedNavigatorId = result.navigator.id;
        _isSearchingDestination = false;
      });

      ViNavigationSession.instance.setNavigating(true);
      _timelineTracker.startTracking(result.destination);
      await _persistNavigationStart(result);
      await _fitRouteOnMap(result);
      _showSnack(
        usedRoadRoute
            ? 'Navigating to ${place.name}'
            : 'Route preview limited — showing direct path to ${place.name}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearchingDestination = false);
      _showSnack('Could not start navigation to ${place.name}');
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
    if (pin != null &&
        (pin.name.toLowerCase() == query.toLowerCase() ||
            query.toLowerCase().contains(pin.name.toLowerCase()))) {
      await _selectDestinationPlace(pin);
      return;
    }

    setState(() => _isSearchingDestination = true);
    final matches = await _destinationSearch.searchAsMapPlaces(
      query: query,
      near: _locationService.livePosition,
      radiusMeters: _useWiderSearch ? 15000 : 5000,
      wider: _useWiderSearch,
    );
    if (!mounted) return;

    if (matches.isNotEmpty) {
      await _selectDestinationPlace(matches.first);
      return;
    }

    setState(() {
      _isSearchingDestination = false;
      _showSearchEmpty = true;
      _destinationSuggestions = [];
    });
  }

  Future<void> _onMapPinDestination(LatLng point) async {
    if (!_isNavigatorMode || _isNavigating || _isResolvingMapPin) return;

    setState(() {
      _isResolvingMapPin = true;
      _followCamera = false;
      _destinationSuggestions = [];
    });

    try {
      final place = await _placeService.placeFromCoordinates(point);
      if (!mounted) return;

      setState(() {
        _pinnedDestination = place;
        _destinationController.text = place.name;
        _isResolvingMapPin = false;
      });

      await _mapController?.animateToLatLng(point, zoom: 16);
      // Pinning confirms the destination — start the route from current GPS.
      await _selectDestinationPlace(place);
    } catch (_) {
      if (!mounted) return;
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
    if (!_isNavigatorMode || !_followCamera) return null;
    return _locationService.livePosition;
  }



  Future<void> _openNavigatorMonitor() async {

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

    final target = _isNavigatorMode ? _liveNavigatorPosition : navigator.location;

    await _mapController?.animateToLatLng(target, zoom: 15);

  }



  Future<void> _fitAllNavigatorsOnMap() async {

    if (_mapController == null) return;



    final points = _navigators.map((n) => n.location).toList()

      ..add(GabayMapDefaults.caregiverLocation);



    await _mapController!.fitBounds(points, padding: 80);

  }



  Future<void> _openRoutePlanner() async {

    final result = await context.pushGabayPage<RoutePlanResult>(
      RoutePlannerPage(
        initialNavigatorId: _activeRoute?.navigator.id ?? _selectedNavigatorId,
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

      ViNavigationSession.instance.setNavigating(true);

      await _persistNavigationStart(result);

      _showSnack('Navigation started — live route shared with your caregiver');

    }

    _timelineTracker.startTracking(result.destination);

    await _fitRouteOnMap(result);

  }



  void _collapseEtaPanel() {

    setState(() => _isEtaPanelVisible = false);

  }



  Future<void> _cancelDestination() async {

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

      GabayMapMarkerData(

        id: 'caregiver',

        position: GabayMapDefaults.caregiverLocation,

        kind: GabayMapMarkerKind.caregiver,

        title: 'Caregiver',

        snippet: GabayMapDefaults.caregiverAddress,

      ),

    ];



    for (var i = 0; i < _navigators.length; i++) {

      final navigator = _navigators[i];

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
              googleMarkerIcons: _mapIcons,
              followUser: _isNavigatorMode && _followCamera,
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
                    unawaited(
                      controller.animateToLatLng(live, zoom: 16),
                    );
                  } else {
                    // Keep trying until GPS arrives.
                    unawaited(_locationService.refreshCurrentLocation());
                  }
                } else if (_showAllNavigatorsOnMap) {
                  _fitAllNavigatorsOnMap();
                }
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
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
                elevation: 3,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        onPressed: () =>
                            unawaited(_locationService.refreshCurrentLocation()),
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
                      _destinationController.clear();
                      setState(() {
                        _destinationSuggestions = [];
                        _pinnedDestination = null;
                        _showSearchEmpty = false;
                        _selectedCategoryQuery = null;
                        _useWiderSearch = false;
                      });
                    },
                    onCancelNavigation: _isNavigating ? _cancelDestination : null,
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
                      unawaited(
                        _runNearbyDestinationSearch(q, wider: true),
                      );
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
                    onTap: _openNavigatorMonitor,
                  ),

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
                      onClose: () => setState(() => _isTurnByTurnVisible = false),
                    ),

                    secondChild: Align(

                      alignment: Alignment.centerRight,

                      child: OpenTurnByTurnButton(

                        onPressed: () => setState(() => _isTurnByTurnVisible = true),

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

                        onPressed: () => setState(() => _isEtaPanelVisible = true),

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

            child: MapZoomControls(

              onZoomIn: _zoomIn,

              onZoomOut: _zoomOut,

            ),

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

  final VoidCallback? onTap;



  const _CurrentAddressCard({

    required this.navigatorName,

    this.showNavigatorName = true,

    required this.address,

    required this.status,

    required this.isLive,

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

                        style: GabayTheme.bodyLarge(context).copyWith(fontSize: 15),

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

                  ],

                ),

              ),

              if (isLive)

                Container(

                  padding:

                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),

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

                Icon(

                  Icons.keyboard_arrow_down_rounded,

                  color: g.textSecondary,

                ),

              ],

            ],

          ),

        ),

      ),

    );

  }

}

