import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/linked_navigator.dart';
import '../models/route_plan.dart';
import 'navigator_location_service.dart';

/// Place search + routing helpers.
///
/// Nearby search uses OpenStreetMap Nominatim biased to the user's GPS,
/// so queries like "Elementary" return schools near the user — not only
/// hardcoded Davao/Panabo stubs.
class MapPlaceService {
  MapPlaceService._();

  static final MapPlaceService instance = MapPlaceService._();

  static const _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const _userAgent = 'AKAY-GABAY/1.0 (accessibility-navigation-app)';

  static const List<MapPlace> recentPlaces = [
    MapPlace(
      id: 'recent_sasa_wharf',
      name: 'Sasa Wharf',
      address: 'Sasa, Davao City, Davao del Sur',
      latitude: 7.1073,
      longitude: 125.6328,
      distance: '18.4 km',
    ),
    MapPlace(
      id: 'recent_city_hall',
      name: 'Panabo City Hall',
      address: 'Quezon Avenue, Panabo City',
      latitude: 7.3089,
      longitude: 125.6834,
      distance: '1.2 km',
    ),
    MapPlace(
      id: 'recent_gaisano',
      name: 'Gaisano Mall',
      address: 'J.P. Laurel Ave, Panabo City',
      latitude: 7.3012,
      longitude: 125.6910,
      distance: '2.8 km',
    ),
    MapPlace(
      id: 'recent_sm_lanang',
      name: 'SM Lanang',
      address: 'JP Laurel Ave, Davao City',
      latitude: 7.0983,
      longitude: 125.6089,
      distance: '24.1 km',
    ),
  ];

  static const List<MapPlace> savedPlaces = [
    MapPlace(
      id: 'saved_home',
      name: 'Home',
      address: 'Lemonito St, New Visayas, Panabo City',
      latitude: 7.3125,
      longitude: 125.6790,
      isSaved: true,
    ),
    MapPlace(
      id: 'saved_work',
      name: 'Work',
      address: 'Tagum-Panabo Highway, Panabo City',
      latitude: 7.2950,
      longitude: 125.7020,
      isSaved: true,
    ),
    MapPlace(
      id: 'saved_hospital',
      name: 'Hospital',
      address: 'Panabo Health Center, Panabo City',
      latitude: 7.3048,
      longitude: 125.6880,
      isSaved: true,
    ),
    MapPlace(
      id: 'saved_police',
      name: 'Police Station',
      address: 'City Police Station, Panabo City',
      latitude: 7.3075,
      longitude: 125.6810,
      isSaved: true,
    ),
  ];

  /// Legacy sync search (saved/recent only). Prefer [searchNearbyPlaces].
  List<MapPlace> searchPlaces(String query, {LatLng? near}) {
    if (query.trim().isEmpty) return [];
    final origin = near ?? NavigatorLocationService.instance.livePosition;
    return _filterLocalPlaces(query, origin);
  }

  /// Async nearby search: Nominatim results around [near], plus local matches.
  Future<List<MapPlace>> searchNearbyPlaces(
    String query, {
    LatLng? near,
    int limit = 12,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final origin = near ?? NavigatorLocationService.instance.livePosition;
    final local = _filterLocalPlaces(trimmed, origin);

    if (origin == null) {
      return local;
    }

    try {
      final remote = await _nominatimSearch(trimmed, origin, limit: limit);
      return _mergeByDistance(local, remote, origin);
    } catch (_) {
      return local;
    }
  }

  /// Reverse-geocode a map pin into a [MapPlace].
  Future<MapPlace> placeFromCoordinates(LatLng point) async {
    final origin = NavigatorLocationService.instance.livePosition;
    try {
      final uri = Uri.parse('$_nominatimBase/reverse').replace(
        queryParameters: {
          'lat': point.latitude.toString(),
          'lon': point.longitude.toString(),
          'format': 'json',
          'addressdetails': '1',
          'zoom': '18',
        },
      );

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': _userAgent,
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          final display = (body['display_name'] as String?)?.trim();
          final name = _shortNameFromNominatim(body) ??
              (display != null && display.isNotEmpty
                  ? display.split(',').first.trim()
                  : 'Pinned location');
          return MapPlace(
            id: 'pin_${point.latitude}_${point.longitude}',
            name: name,
            address: display ?? _coordLabel(point),
            latitude: point.latitude,
            longitude: point.longitude,
            distance: origin == null ? null : _formatDistance(origin, point),
          );
        }
      }
    } catch (_) {
      // Fall through to coordinate label.
    }

    return MapPlace(
      id: 'pin_${point.latitude}_${point.longitude}',
      name: 'Pinned destination',
      address: _coordLabel(point),
      latitude: point.latitude,
      longitude: point.longitude,
      distance: origin == null ? null : _formatDistance(origin, point),
    );
  }

  Future<List<MapPlace>> _nominatimSearch(
    String query,
    LatLng near, {
    int limit = 12,
  }) async {
    // ~10 km viewbox around the user to bias "nearest" results.
    const delta = 0.09;
    final left = near.longitude - delta;
    final right = near.longitude + delta;
    final top = near.latitude + delta;
    final bottom = near.latitude - delta;

    final uri = Uri.parse('$_nominatimBase/search').replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'limit': '$limit',
        'lat': '${near.latitude}',
        'lon': '${near.longitude}',
        'viewbox': '$left,$top,$right,$bottom',
        'bounded': '0',
      },
    );

    final response = await http
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'User-Agent': _userAgent,
          },
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];

    final places = <MapPlace>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final lat = double.tryParse('${map['lat']}');
      final lon = double.tryParse('${map['lon']}');
      if (lat == null || lon == null) continue;

      final point = LatLng(lat, lon);
      final display = (map['display_name'] as String?)?.trim() ?? '';
      final name = _shortNameFromNominatim(map) ??
          (display.isNotEmpty ? display.split(',').first.trim() : query);

      final meters = _meters(near, point).round();
      places.add(
        MapPlace(
          id: 'osm_${map['place_id'] ?? '${lat}_$lon'}',
          name: name,
          address: display.isNotEmpty ? display : _coordLabel(point),
          latitude: lat,
          longitude: lon,
          distance: _formatDistance(near, point),
          walkingTime: _formatWalkingTime(meters),
          source: 'OpenStreetMap',
          distanceMeters: meters,
          category: _categoryFromNominatim(map),
        ),
      );
    }

    places.sort((a, b) {
      final da = _meters(near, a.latLng);
      final db = _meters(near, b.latLng);
      return da.compareTo(db);
    });

    return places;
  }

  List<MapPlace> _filterLocalPlaces(String query, LatLng? origin) {
    final normalized = query.toLowerCase();
    final all = [...recentPlaces, ...savedPlaces];
    final matches = all
        .where(
          (place) =>
              place.name.toLowerCase().contains(normalized) ||
              place.address.toLowerCase().contains(normalized),
        )
        .map((place) {
          if (origin == null) return place;
          return place.copyWith(distance: _formatDistance(origin, place.latLng));
        })
        .toList();

    if (origin != null) {
      matches.sort(
        (a, b) => _meters(origin, a.latLng).compareTo(_meters(origin, b.latLng)),
      );
    }
    return matches;
  }

  List<MapPlace> _mergeByDistance(
    List<MapPlace> local,
    List<MapPlace> remote,
    LatLng origin,
  ) {
    final seen = <String>{};
    final merged = <MapPlace>[];

    for (final place in [...remote, ...local]) {
      final key = '${place.name.toLowerCase()}_${place.latitude.toStringAsFixed(4)}';
      if (seen.contains(key)) continue;
      seen.add(key);
      merged.add(
        place.distance == null
            ? place.copyWith(distance: _formatDistance(origin, place.latLng))
            : place,
      );
    }

    merged.sort(
      (a, b) => _meters(origin, a.latLng).compareTo(_meters(origin, b.latLng)),
    );
    return merged.take(12).toList();
  }

  String? _shortNameFromNominatim(Map<String, dynamic> map) {
    final named = map['name'] as String?;
    if (named != null && named.trim().isNotEmpty) return named.trim();

    final address = map['address'];
    if (address is Map) {
      for (final key in [
        'amenity',
        'shop',
        'building',
        'tourism',
        'leisure',
        'highway',
        'school',
        'university',
        'hospital',
        'suburb',
        'road',
      ]) {
        final value = address[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
    return null;
  }

  double _meters(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  String _formatDistance(LatLng from, LatLng to) {
    final meters = _meters(from, to);
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  String _formatWalkingTime(int meters) {
    final minutes = (meters / 75).round().clamp(1, 999);
    return '$minutes mins';
  }

  String _categoryFromNominatim(Map<String, dynamic> map) {
    final address = map['address'];
    if (address is Map) {
      for (final key in [
        'amenity',
        'shop',
        'tourism',
        'leisure',
        'office',
        'healthcare',
      ]) {
        final value = address[key];
        if (value is String && value.trim().isNotEmpty) {
          final raw = value.replaceAll('_', ' ');
          return raw[0].toUpperCase() + raw.substring(1);
        }
      }
    }
    final type = map['type'];
    if (type is String && type.trim().isNotEmpty) {
      final raw = type.replaceAll('_', ' ');
      return raw[0].toUpperCase() + raw.substring(1);
    }
    return 'Place';
  }

  String _coordLabel(LatLng point) {
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  /// Builds a route using real walking directions (OSRM) so the blue line
  /// follows roads/paths — not a decorative curve.
  Future<RoutePlanResult> buildRoutePlan({
    required LinkedNavigator navigator,
    required MapPlace destination,
  }) async {
    final origin = navigator.location;
    final routed = await fetchWalkingRoute(origin, destination.latLng);

    final polyline = routed?.points ??
        <LatLng>[origin, destination.latLng];
    final estimatedTime = routed?.durationLabel ??
        GabayMapDefaults.mockEta(origin, destination.latLng);
    final estimatedDistance = routed?.distanceLabel ??
        GabayMapDefaults.mockDistance(origin, destination.latLng);

    final steps = routed?.steps.isNotEmpty == true
        ? routed!.steps
        : _fallbackSteps(destination.name);

    return RoutePlanResult(
      navigator: navigator,
      destination: destination,
      estimatedTime: estimatedTime,
      estimatedDistance: estimatedDistance,
      currentSpeed: '—',
      navigationStatus:
          'Navigating to ${destination.name}',
      polylinePoints: polyline,
      tripStartedAt: DateTime.now(),
      turnInstructions: steps,
    );
  }

  List<RouteTurnInstruction> _fallbackSteps(String destinationName) {
    return [
      RouteTurnInstruction(
        instruction: 'Head toward $destinationName',
        detail: 'Follow the highlighted route',
        maneuverType: 'depart',
        isNext: true,
      ),
      const RouteTurnInstruction(
        instruction: 'Continue along the route',
        maneuverType: 'new name',
      ),
      RouteTurnInstruction(
        instruction: 'Arrive at $destinationName',
        detail: 'Destination',
        maneuverType: 'arrive',
      ),
    ];
  }

  /// Walking/foot directions via public OSRM (OpenStreetMap road network).
  Future<OsrmRouteGeometry?> fetchWalkingRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    // OSRM expects lon,lat order.
    final coords =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/foot/$coords',
    ).replace(
      queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'true',
      },
    );

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': _userAgent,
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
      if (body['code'] != 'Ok') return null;

      final routes = body['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final route = routes.first;
      if (route is! Map) return null;

      final geometry = route['geometry'];
      if (geometry is! Map) return null;
      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.length < 2) return null;

      final points = <LatLng>[];
      for (final coord in coordinates) {
        if (coord is! List || coord.length < 2) continue;
        final lon = (coord[0] as num?)?.toDouble();
        final lat = (coord[1] as num?)?.toDouble();
        if (lat == null || lon == null) continue;
        points.add(LatLng(lat, lon));
      }
      if (points.length < 2) return null;

      final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0;
      final durationSeconds = (route['duration'] as num?)?.toDouble() ?? 0;
      final steps = _parseOsrmSteps(route);

      return OsrmRouteGeometry(
        points: points,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        steps: steps,
      );
    } catch (_) {
      return null;
    }
  }

  List<RouteTurnInstruction> _parseOsrmSteps(Map route) {
    final legs = route['legs'];
    if (legs is! List || legs.isEmpty) return const [];

    final instructions = <RouteTurnInstruction>[];
    for (final leg in legs) {
      if (leg is! Map) continue;
      final steps = leg['steps'];
      if (steps is! List) continue;

      for (final step in steps) {
        if (step is! Map) continue;
        final maneuver = step['maneuver'];
        if (maneuver is! Map) continue;

        final type = '${maneuver['type'] ?? 'turn'}';
        final modifier = '${maneuver['modifier'] ?? ''}';
        final roadName = '${step['name'] ?? ''}'.trim();
        final distance = (step['distance'] as num?)?.toDouble() ?? 0;

        // Skip tiny unnamed intermediate nodes that clutter the list.
        if (type == 'new name' && roadName.isEmpty && distance < 15) {
          continue;
        }

        final instruction = _humanizeManeuver(
          type: type,
          modifier: modifier,
          roadName: roadName,
        );
        if (instruction.isEmpty) continue;

        instructions.add(
          RouteTurnInstruction(
            instruction: instruction,
            detail: distance > 0 ? _formatStepDistance(distance) : '',
            maneuverType: type,
            modifier: modifier,
          ),
        );
      }
    }

    if (instructions.isEmpty) return const [];

    // Mark the first actionable step as "next".
    return [
      instructions.first.copyWith(isNext: true),
      ...instructions.skip(1),
    ];
  }

  String _humanizeManeuver({
    required String type,
    required String modifier,
    required String roadName,
  }) {
    final onto = roadName.isNotEmpty ? ' onto $roadName' : '';
    final on = roadName.isNotEmpty ? ' on $roadName' : '';

    switch (type) {
      case 'depart':
        return roadName.isNotEmpty
            ? 'Start on $roadName'
            : 'Start navigation';
      case 'arrive':
        return 'Arrive at your destination';
      case 'turn':
        return 'Turn ${_modifierPhrase(modifier)}$onto';
      case 'new name':
        return roadName.isNotEmpty
            ? 'Continue on $roadName'
            : 'Continue straight';
      case 'merge':
        return 'Merge${_modifierPhrase(modifier, prefix: ' ')}$onto';
      case 'fork':
        return 'Keep ${_modifierPhrase(modifier)}$onto';
      case 'end of road':
        return 'At the end of the road, turn ${_modifierPhrase(modifier)}$onto';
      case 'continue':
        return 'Continue${_modifierPhrase(modifier, prefix: ' ')}$on';
      case 'roundabout':
      case 'rotary':
        return 'Enter the roundabout${_modifierPhrase(modifier, prefix: ' and take the ')}$onto';
      case 'notification':
        return roadName.isNotEmpty ? roadName : 'Continue along the route';
      default:
        if (modifier.isNotEmpty) {
          return '${_capitalize(_modifierPhrase(modifier))}$onto';
        }
        return roadName.isNotEmpty ? 'Follow $roadName' : 'Continue along the route';
    }
  }

  String _modifierPhrase(String modifier, {String prefix = ''}) {
    if (modifier.isEmpty) return prefix.isEmpty ? 'ahead' : '';
    final cleaned = modifier.replaceAll('_', ' ');
    return '$prefix$cleaned';
  }

  String _capitalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  String _formatStepDistance(double meters) {
    if (meters >= 1000) {
      return 'In ${(meters / 1000).toStringAsFixed(1)} km';
    }
    return 'In ${meters.round()} m';
  }
}

/// Geometry + labels from an OSRM walking route response.
class OsrmRouteGeometry {
  const OsrmRouteGeometry({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.steps = const [],
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteTurnInstruction> steps;

  String get distanceLabel {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  String get durationLabel {
    final minutes = (durationSeconds / 60).round().clamp(1, 999);
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }
    return '$minutes min';
  }
}
