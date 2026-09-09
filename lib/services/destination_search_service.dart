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
