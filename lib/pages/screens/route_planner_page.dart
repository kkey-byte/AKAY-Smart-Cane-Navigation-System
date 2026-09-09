import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/linked_navigator.dart';
import '../../models/route_plan.dart';
import '../../services/app_session_service.dart';
import '../../services/destination_search_service.dart';
import '../../services/map_place_service.dart';
import '../../services/navigator_location_service.dart';
import '../../theme/gabay_theme.dart';
import '../../widgets/track/route_search_card.dart';

class RoutePlannerPage extends StatefulWidget {
  const RoutePlannerPage({
    super.key,
    required this.initialNavigatorId,
    this.isNavigatorMode = false,
  });

  final String initialNavigatorId;
  final bool isNavigatorMode;

  @override
  State<RoutePlannerPage> createState() => _RoutePlannerPageState();
}

class _RoutePlannerPageState extends State<RoutePlannerPage> {
  late LinkedNavigator _selected;
  final _destinationController = TextEditingController();
  final _destinationFocus = FocusNode();
  final _location = NavigatorLocationService.instance;
  final _placeService = MapPlaceService.instance;
  final _destinationSearch = DestinationSearchService.instance;

  List<MapPlace> _suggestions = const [];
  bool _isSearching = false;
  String? _originAddress;
  Timer? _searchDebounce;
  int _searchToken = 0;

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

  bool get _useLiveOrigin => widget.isNavigatorMode;

  @override
  void initState() {
    super.initState();
    _selected = widget.isNavigatorMode
        ? LinkedNavigatorService.selfNavigator
        : (LinkedNavigatorService.instance.findById(widget.initialNavigatorId) ??
            LinkedNavigatorService.navigators.first);

    _destinationController.addListener(_onQueryChanged);
    if (_useLiveOrigin) {
      _location.addListener(_onLocationChanged);
      unawaited(_bootstrapLiveOrigin());
    } else {
      _originAddress = _selected.address;
    }
  }

  Future<void> _bootstrapLiveOrigin() async {
    await _location.startTracking();
    await _refreshOriginLabel();
  }

  void _onLocationChanged() {
    if (!mounted) return;
    unawaited(_refreshOriginLabel());
  }

  Future<void> _refreshOriginLabel() async {
    if (!_useLiveOrigin) return;

    final pos = _location.livePosition;
    if (pos == null) {
      if (!mounted) return;
      setState(() => _originAddress = null);
      return;
    }

    // Prefer the service reverse-geocode when available.
    final cached = _location.address.trim();
    if (cached.isNotEmpty &&
        cached != 'Locating you…' &&
        !cached.toLowerCase().contains('locating')) {
      if (!mounted) return;
      setState(() => _originAddress = cached);
      return;
    }

    final place = await _placeService.placeFromCoordinates(pos);
    if (!mounted) return;
    setState(() {
      _originAddress = place.address.isNotEmpty
          ? place.address
          : '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
    });
  }

  void _onQueryChanged() {
    _searchDebounce?.cancel();
    final query = _destinationController.text.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 380), () {
      unawaited(_runSearch(query));
    });
  }

  Future<void> _runSearch(String query) async {
    final token = ++_searchToken;
    final near = _useLiveOrigin
        ? _location.livePosition
        : _selected.location;

    final results = await _destinationSearch.searchAsMapPlaces(
      query: query,
      near: near,
      radiusMeters: 5000,
    );

    if (!mounted || token != _searchToken) return;
    setState(() {
      _suggestions = results;
      _isSearching = false;
    });
  }

  Future<void> _onSuggestionSelected(MapPlace place) async {
    FocusScope.of(context).unfocus();

    LinkedNavigator navigator = _selected;
    if (_useLiveOrigin) {
      final live = _location.livePosition;
      if (live == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Still locating you. Please wait for GPS, then try again.'),
          ),
        );
        await _location.refreshCurrentLocation();
        return;
      }
      navigator = LinkedNavigator(
        id: LinkedNavigatorService.selfNavigator.id,
        name: _sessionNavigatorFullName,
        address: _originAddress ?? _location.address,
        location: live,
        status: 'Navigating',
        batteryPercent: LinkedNavigatorService.selfNavigator.batteryPercent,
        isOnline: true,
      );
    }

    final result = await _placeService.buildRoutePlan(
      navigator: navigator,
      destination: place,
    );
    if (!mounted) return;
    Navigator.of(context).pop<RoutePlanResult>(result);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    if (_useLiveOrigin) {
      _location.removeListener(_onLocationChanged);
    }
    _destinationController.removeListener(_onQueryChanged);
    _destinationController.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: g.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Route Planner',
          style: TextStyle(
            color: g.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RouteSearchCard(
                navigators: LinkedNavigatorService.navigators,
                selectedNavigator: _selected,
                onNavigatorChanged: (n) {
                  setState(() {
                    _selected = n;
                    if (!_useLiveOrigin) {
                      _originAddress = n.address;
                    }
                  });
                },
                destinationController: _destinationController,
                destinationFocusNode: _destinationFocus,
                onSwap: () {},
                suggestions: _suggestions,
                onSuggestionSelected: (place) => unawaited(_onSuggestionSelected(place)),
                showNavigatorPicker: !widget.isNavigatorMode,
                originAddress: _originAddress,
                originTitle: widget.isNavigatorMode
                    ? 'Your current location'
                    : "${_selected.name}'s Location",
                isSearching: _isSearching,
              ),
              if (_isSearching && _suggestions.isEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Searching nearest places…',
                    style: TextStyle(color: g.textSecondary, fontSize: 13),
                  ),
                ),
              ],
              if (!_isSearching &&
                  _destinationController.text.trim().length >= 2 &&
                  _suggestions.isEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'No nearby places found. Try another keyword.',
                    style: TextStyle(color: g.textSecondary, fontSize: 13),
                  ),
                ),
              ],
              if (widget.isNavigatorMode) ...[
                const SizedBox(height: 20),
                Text(
                  'Tip: On the Track map, tap or long-press to pin a destination.',
                  style: TextStyle(
                    color: g.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
