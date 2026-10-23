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
    this.linkedNavigators,
    this.placeService,
    this.destinationSearch,
  });

  final String initialNavigatorId;
  final bool isNavigatorMode;
  final List<LinkedNavigator>? linkedNavigators;
  final MapPlaceService? placeService;
  final DestinationSearchService? destinationSearch;

  @override
  State<RoutePlannerPage> createState() => _RoutePlannerPageState();
}

class _RoutePlannerPageState extends State<RoutePlannerPage> {
  late LinkedNavigator _selected;
  final _destinationController = TextEditingController();
  final _destinationFocus = FocusNode();
  final _location = NavigatorLocationService.instance;
  late final _placeService = widget.placeService ?? MapPlaceService.instance;
  late final _destinationSearch =
      widget.destinationSearch ?? DestinationSearchService.instance;

  List<MapPlace> _suggestions = const [];
  List<MapPlace> _recentDestinations = const [];
  bool _isSearching = false;
  String? _originAddress;
  String? _searchError;
  bool _hasSearched = false;
  int _searchToken = 0;
  int? _routeRequestToken;
  MapPlace? _routingPlace;
  int _recentDestinationToken = 0;

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
        : (widget.linkedNavigators
                  ?.where(
                    (navigator) => navigator.id == widget.initialNavigatorId,
                  )
                  .firstOrNull ??
              LinkedNavigatorService.instance.findById(
                widget.initialNavigatorId,
              ) ??
              LinkedNavigatorService.navigators.first);

    _destinationController.addListener(_onQueryChanged);
    unawaited(_loadRecentDestinations());
    if (_useLiveOrigin) {
      _location.addListener(_onLocationChanged);
      unawaited(_bootstrapLiveOrigin());
    } else {
      _originAddress = _selected.address;
    }
  }

  Future<void> _loadRecentDestinations() async {
    final navigatorId = _selected.id;
    final token = ++_recentDestinationToken;
    final destinations = await _destinationSearch.loadRecentSentDestinations(
      navigatorId,
    );
    if (!mounted ||
        token != _recentDestinationToken ||
        _selected.id != navigatorId) {
      return;
    }
    setState(() => _recentDestinations = destinations);
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
    _searchToken++;
    setState(() {
      _suggestions = const [];
      _isSearching = false;
      _searchError = null;
      _hasSearched = false;
    });
  }

  Future<void> _runSearch(String query) async {
    final token = ++_searchToken;
    final near = _useLiveOrigin ? _location.livePosition : _selected.location;

    setState(() {
      _isSearching = true;
      _searchError = null;
      _hasSearched = true;
    });
    try {
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
    } catch (_) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _isSearching = false;
        _searchError = 'Search unavailable. Check your connection and retry.';
      });
    }
  }

  Future<void> _onSuggestionSelected(MapPlace place) async {
    if (_routeRequestToken == _searchToken &&
        _routingPlace?.latitude == place.latitude &&
        _routingPlace?.longitude == place.longitude) {
      return;
    }
    final token = ++_searchToken;
    _routeRequestToken = token;
    _routingPlace = place;
    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);
    try {
      LinkedNavigator navigator = _selected;
      if (_useLiveOrigin) {
        var live = _location.livePosition;
        if (live == null) {
          await _location.refreshCurrentLocation();
          if (!mounted || token != _searchToken) return;
          live = _location.livePosition;
          if (live == null) {
            throw NavigationRouteException(
              _location.errorMessage ??
                  'Current location is unavailable. Allow location access, then retry this destination.',
            );
          }
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
      if (!mounted || token != _searchToken) return;
      // Local history must not prevent an otherwise valid route from opening.
      try {
        await _destinationSearch.saveRecentSentDestination(
          navigatorId: _selected.id,
          place: place,
        );
      } catch (_) {}
      if (!mounted || token != _searchToken) return;
      Navigator.of(context).pop<RoutePlanResult>(result);
    } catch (error) {
      if (!mounted || token != _searchToken) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is NavigationRouteException
                ? error.message
                : 'Could not start navigation. Please retry this destination.',
          ),
        ),
      );
    } finally {
      if (_routeRequestToken == token) _routeRequestToken = null;
      if (mounted && token == _searchToken) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _useRecentDestination(MapPlace place) {
    if (_destinationController.text != place.name) {
      _destinationController.text = place.name;
      _destinationController.selection = TextSelection.collapsed(
        offset: place.name.length,
      );
    }
    unawaited(_onSuggestionSelected(place));
  }

  @override
  void dispose() {
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
                navigators:
                    widget.linkedNavigators ??
                    LinkedNavigatorService.navigators,
                selectedNavigator: _selected,
                onNavigatorChanged: (n) {
                  _searchToken++;
                  setState(() {
                    _isSearching = false;
                    _selected = n;
                    if (!_useLiveOrigin) {
                      _originAddress = n.address;
                    }
                  });
                  unawaited(_loadRecentDestinations());
                },
                destinationController: _destinationController,
                destinationFocusNode: _destinationFocus,
                onSwap: () {},
                suggestions: _suggestions,
                onSuggestionSelected: (place) =>
                    unawaited(_onSuggestionSelected(place)),
                showNavigatorPicker: !widget.isNavigatorMode,
                originAddress: _originAddress,
                originTitle: widget.isNavigatorMode
                    ? 'Your current location'
                    : "${_selected.name}'s Location",
                isSearching: _isSearching,
                onSearch: () =>
                    unawaited(_runSearch(_destinationController.text.trim())),
              ),
              const SizedBox(height: 20),
              _RecentDestinationsSection(
                destinations: _recentDestinations,
                onDestinationTap: _useRecentDestination,
              ),
              if (_isSearching && _suggestions.isEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _routeRequestToken == _searchToken
                        ? 'Preparing walking route...'
                        : 'Searching nearest places...',
                    style: TextStyle(color: g.textSecondary, fontSize: 13),
                  ),
                ),
              ],
              if (_searchError != null) Text(_searchError!),
              if (_hasSearched &&
                  _searchError == null &&
                  !_isSearching &&
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

class _RecentDestinationsSection extends StatelessWidget {
  const _RecentDestinationsSection({
    required this.destinations,
    required this.onDestinationTap,
  });

  final List<MapPlace> destinations;
  final ValueChanged<MapPlace> onDestinationTap;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Destinations',
          style: TextStyle(
            color: g.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (destinations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No recent destinations yet.',
              style: TextStyle(color: g.textSecondary, fontSize: 13),
            ),
          )
        else
          Container(
            decoration: GabayTheme.cardDecoration(context),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < destinations.length && index < 3;
                    index++
                  ) ...[
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      leading: Icon(
                        Icons.history_rounded,
                        color: g.accent,
                        size: 22,
                      ),
                      title: Text(
                        destinations[index].displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: g.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        destinations[index].shortAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: g.textSecondary, fontSize: 12),
                      ),
                      trailing: Icon(
                        Icons.north_east_rounded,
                        color: g.textSecondary,
                        size: 18,
                      ),
                      onTap: () => onDestinationTap(destinations[index]),
                    ),
                    if (index < destinations.length - 1 && index < 2)
                      Divider(height: 1, color: g.border),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
