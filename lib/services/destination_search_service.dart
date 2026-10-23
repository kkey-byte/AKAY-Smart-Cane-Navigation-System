import 'secure_api.dart';
import 'package:flutter/foundation.dart';
import 'app_session_service.dart';
import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/route_plan.dart';
import '../models/search_destination.dart';

/// Destination search through the configured AKAY API. Errors remain distinct
/// from successful empty results; no second provider silently receives a query.
class DestinationSearchService {
  DestinationSearchService({http.Client? client, this.baseUrl})
    : _client = client ?? http.Client();
  final http.Client _client;
  final String? baseUrl;

  static final DestinationSearchService instance = DestinationSearchService();

  static const _recentKey = 'akay_recent_destination_searches';
  static const _maxRecent = 8;
  String? _accountKey(String base) {
    final session = AppSessionService.instance;
    if (!session.isLoggedIn) return null;
    final owner = session.userId ?? session.email;
    return owner == null ? null : '$base:${Uri.encodeComponent(owner)}';
  }

  static const _recentSentDestinationsKey = 'akay_recent_sent_destinations_v1';
  static const _maxRecentSentDestinationsPerNavigator = 3;

  /// Search nearby destinations. Prefer backend `/api/search`.
  Future<List<SearchDestination>> search({
    required String query,
    LatLng? near,
    int radiusMeters = 5000,
    bool wider = false,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    if (near == null) {
      throw StateError(
        'Current location is unavailable. Enable location and try again.',
      );
    }
    return _searchApi(
      query: trimmed,
      near: near,
      radiusMeters: radiusMeters,
      wider: wider,
    );
  }

  Future<List<SearchDestination>> _searchApi({
    required String query,
    required LatLng near,
    required int radiusMeters,
    required bool wider,
  }) async {
    try {
      final uri =
          Uri.parse(
            '${baseUrl ?? SecureApi.preferredBase ?? ApiConfig.baseUrl}/search',
          ).replace(
            queryParameters: {
              'query': query,
              'latitude': '${near.latitude}',
              'longitude': '${near.longitude}',
              'radius': '$radiusMeters',
              if (wider) 'wider': '1',
            },
          );

      if (kReleaseMode && uri.scheme != 'https') {
        throw StateError('Configure an HTTPS search API.');
      }
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 14));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Destination search is unavailable. Please retry.');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const FormatException('Invalid search response.');
      }

      return decoded
          .whereType<Map>()
          .map((e) => SearchDestination.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.name.isNotEmpty)
          .toList();
    } catch (_) {
      throw StateError('Destination search is unavailable. Please retry.');
    }
  }

  Future<List<String>> loadRecentQueries() async {
    final key = _accountKey(_recentKey);
    if (key == null) return const [];
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? const [];
  }

  Future<void> saveRecentQuery(String query) async {
    final key = _accountKey(_recentKey);
    if (key == null) return;
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(key) ?? <String>[];
    current.removeWhere((q) => q.toLowerCase() == trimmed.toLowerCase());
    current.insert(0, trimmed);
    await prefs.setStringList(key, current.take(_maxRecent).toList());
  }

  Future<void> clearRecentQueries() async {
    final key = _accountKey(_recentKey);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// Saves a destination after it has been sent to a navigator. This local
  /// history is kept separately from search terms so the UI can retain both
  /// the destination name and its full address.
  Future<void> saveRecentSentDestination({
    required String navigatorId,
    required MapPlace place,
  }) async {
    final key = _accountKey(_recentSentDestinationsKey);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    final current = await _loadRecentSentDestinations(key);
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
      key,
      jsonEncode(retained.map((entry) => entry.toJson()).toList()),
    );
  }

  /// Returns the three most recently sent destinations for one navigator.
  Future<List<MapPlace>> loadRecentSentDestinations(String navigatorId) async {
    final key = _accountKey(_recentSentDestinationsKey);
    if (key == null) return const [];
    final entries = await _loadRecentSentDestinations(key);
    return entries
        .where((entry) => entry.navigatorId == navigatorId)
        .take(_maxRecentSentDestinationsPerNavigator)
        .map((entry) => entry.place)
        .toList();
  }

  Future<List<_RecentSentDestination>> _loadRecentSentDestinations(
    String key,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(key);
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
    if (navigatorId.isEmpty ||
        name.isEmpty ||
        latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
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
