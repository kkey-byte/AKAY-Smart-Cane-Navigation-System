import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/route_plan.dart';
import '../models/search_destination.dart';
import 'map_place_service.dart';

/// Smart destination search: AKAY API (Nominatim + PostgreSQL) with
/// client-side fallback to direct Nominatim via [MapPlaceService].
class DestinationSearchService {
  DestinationSearchService._();

  static final DestinationSearchService instance = DestinationSearchService._();

  static const _recentKey = 'akay_recent_destination_searches';
  static const _maxRecent = 8;
  static const _recentSentDestinationsKey =
      'akay_recent_sent_destinations_v1';
  static const _maxRecentSentDestinationsPerNavigator = 3;

  final _placeService = MapPlaceService.instance;

  /// Search nearby destinations. Prefer backend `/api/search`.
  Future<List<SearchDestination>> search({
    required String query,
    LatLng? near,
    int radiusMeters = 5000,
    bool wider = false,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    if (near != null) {
      final apiResults = await _searchApi(
        query: trimmed,
        near: near,
        radiusMeters: radiusMeters,
        wider: wider,
      );
      if (apiResults.isNotEmpty) return apiResults;
    }

    // Fallback: direct OSM + local stubs (works offline from API).
    final fallback = await _placeService.searchNearbyPlaces(
      trimmed,
      near: near,
      limit: 12,
    );
    return fallback.map(SearchDestination.fromMapPlace).toList();
  }

  Future<List<SearchDestination>> _searchApi({
    required String query,
    required LatLng near,
    required int radiusMeters,
    required bool wider,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/search').replace(
        queryParameters: {
          'query': query,
          'latitude': '${near.latitude}',
          'longitude': '${near.longitude}',
          'radius': '$radiusMeters',
          if (wider) 'wider': '1',
        },
      );

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 14));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map>()
          .map((e) => SearchDestination.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.name.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> loadRecentQueries() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentKey) ?? const [];
  }

  Future<void> saveRecentQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_recentKey) ?? <String>[];
    current.removeWhere((q) => q.toLowerCase() == trimmed.toLowerCase());
    current.insert(0, trimmed);
    await prefs.setStringList(
      _recentKey,
      current.take(_maxRecent).toList(),
    );
  }

  Future<void> clearRecentQueries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentKey);
  }

  /// Saves a destination after it has been sent to a navigator. This local
  /// history is kept separately from search terms so the UI can retain both
  /// the destination name and its full address.
  Future<void> saveRecentSentDestination({
    required String navigatorId,
    required MapPlace place,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await _loadRecentSentDestinations();
    current.removeWhere(
      (entry) =>
          entry.navigatorId == navigatorId &&
          entry.place.name.toLowerCase() == place.name.toLowerCase() &&
          entry.place.address.toLowerCase() == place.address.toLowerCase(),
    );
    current.insert(0, _RecentSentDestination(navigatorId, place));

    final currentNavigator = current
        .where((entry) => entry.navigatorId == navigatorId)
        .take(_maxRecentSentDestinationsPerNavigator);
    final otherNavigators = current.where(
      (entry) => entry.navigatorId != navigatorId,
    );
    final retained = [...currentNavigator, ...otherNavigators].take(32);

    await prefs.setString(
      _recentSentDestinationsKey,
      jsonEncode(retained.map((entry) => entry.toJson()).toList()),
    );
  }

  /// Returns the three most recently sent destinations for one navigator.
  Future<List<MapPlace>> loadRecentSentDestinations(String navigatorId) async {
    final entries = await _loadRecentSentDestinations();
    return entries
        .where((entry) => entry.navigatorId == navigatorId)
        .take(_maxRecentSentDestinationsPerNavigator)
        .map((entry) => entry.place)
        .toList();
  }

  Future<List<_RecentSentDestination>> _loadRecentSentDestinations() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_recentSentDestinationsKey);
    if (encoded == null || encoded.isEmpty) return <_RecentSentDestination>[];

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return <_RecentSentDestination>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) => _RecentSentDestination.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .whereType<_RecentSentDestination>()
          .toList();
    } catch (_) {
      return <_RecentSentDestination>[];
    }
  }

  /// Convenience for callers that still use [MapPlace].
  Future<List<MapPlace>> searchAsMapPlaces({
    required String query,
    LatLng? near,
    int radiusMeters = 5000,
    bool wider = false,
  }) async {
    final results = await search(
      query: query,
      near: near,
      radiusMeters: radiusMeters,
      wider: wider,
    );
    return results.map((e) => e.toMapPlace()).toList();
  }
}

class _RecentSentDestination {
  const _RecentSentDestination(this.navigatorId, this.place);

  final String navigatorId;
  final MapPlace place;

  Map<String, dynamic> toJson() => {
        'navigatorId': navigatorId,
        'id': place.id,
        'name': place.name,
        'address': place.address,
        'latitude': place.latitude,
        'longitude': place.longitude,
      };

  static _RecentSentDestination? fromJson(Map<String, dynamic> json) {
    final navigatorId = json['navigatorId']?.toString().trim() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    final address = json['address']?.toString().trim() ?? '';
    final latitude = _asDouble(json['latitude']);
    final longitude = _asDouble(json['longitude']);
    if (navigatorId.isEmpty || name.isEmpty || latitude == null || longitude == null) {
      return null;
    }

    return _RecentSentDestination(
      navigatorId,
      MapPlace(
        id: json['id']?.toString() ?? '$latitude,$longitude',
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
