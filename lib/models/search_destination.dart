import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'route_plan.dart';

/// Unified destination search result (OpenStreetMap + AKAY DB).
class SearchDestination {
  const SearchDestination({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.walkingTime,
    required this.source,
    this.isAccessible = false,
    this.distanceLabel,
  });

  final String id;
  final String name;
  final String category;
  final String address;
  final double latitude;
  final double longitude;
  final int distanceMeters;
  final String walkingTime;
  final String source;
  final bool isAccessible;
  final String? distanceLabel;

  LatLng get latLng => LatLng(latitude, longitude);

  String get displayDistance =>
      distanceLabel ??
      (distanceMeters >= 1000
          ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
          : '$distanceMeters m');

  String get speakText =>
      '$name. $displayDistance away. Approximately $walkingTime.';

  factory SearchDestination.fromJson(Map<String, dynamic> json) {
    final distance = (json['distance'] as num?)?.round() ?? 0;
    return SearchDestination(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? 'Place'}',
      category: '${json['category'] ?? 'Place'}',
      address: '${json['address'] ?? ''}',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      distanceMeters: distance,
      walkingTime: '${json['walkingTime'] ?? ''}',
      source: '${json['source'] ?? 'OpenStreetMap'}',
      isAccessible: json['isAccessible'] == true,
      distanceLabel: json['distanceLabel'] as String?,
    );
  }

  MapPlace toMapPlace() {
    return MapPlace(
      id: id,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      distance: displayDistance,
      category: category,
      walkingTime: walkingTime,
      source: source,
      isAccessible: isAccessible,
      distanceMeters: distanceMeters,
    );
  }

  factory SearchDestination.fromMapPlace(MapPlace place) {
    final meters = place.distanceMeters ??
        _parseDistanceMeters(place.distance) ??
        0;
    return SearchDestination(
      id: place.id,
      name: place.name,
      category: place.category ?? 'Place',
      address: place.address,
      latitude: place.latitude,
      longitude: place.longitude,
      distanceMeters: meters,
      walkingTime: place.walkingTime ?? _estimateWalk(meters),
      source: place.source ?? 'OpenStreetMap',
      isAccessible: place.isAccessible,
      distanceLabel: place.distance,
    );
  }

  static int? _parseDistanceMeters(String? label) {
    if (label == null || label.isEmpty) return null;
    final lower = label.toLowerCase();
    final numMatch = RegExp(r'([\d.]+)').firstMatch(lower);
    if (numMatch == null) return null;
    final value = double.tryParse(numMatch.group(1)!);
    if (value == null) return null;
    if (lower.contains('km')) return (value * 1000).round();
    return value.round();
  }

  static String _estimateWalk(int meters) {
    final minutes = (meters / 75).round().clamp(1, 999);
    return '$minutes mins';
  }
}

/// Quick search category chips shown under the destination search bar.
class SearchCategory {
  const SearchCategory({
    required this.label,
    required this.query,
    required this.icon,
  });

  final String label;
  final String query;
  final String icon; // Material Icons name key used by UI

  static const List<SearchCategory> all = [
    SearchCategory(label: 'Hospital', query: 'hospital', icon: 'local_hospital'),
    SearchCategory(label: 'Restaurant', query: 'restaurant', icon: 'restaurant'),
    SearchCategory(label: 'School', query: 'school', icon: 'school'),
    SearchCategory(label: 'ATM', query: 'atm', icon: 'atm'),
    SearchCategory(label: 'Bank', query: 'bank', icon: 'account_balance'),
    SearchCategory(label: 'Police', query: 'police', icon: 'local_police'),
    SearchCategory(label: 'Fire Station', query: 'fire station', icon: 'local_fire_department'),
    SearchCategory(label: 'Church', query: 'church', icon: 'church'),
    SearchCategory(label: 'Mall', query: 'mall', icon: 'store_mall_directory'),
    SearchCategory(label: 'Market', query: 'market', icon: 'storefront'),
    SearchCategory(label: 'Bus Terminal', query: 'bus terminal', icon: 'directions_bus'),
    SearchCategory(label: 'Hotel', query: 'hotel', icon: 'hotel'),
    SearchCategory(label: 'Park', query: 'park', icon: 'park'),
    SearchCategory(label: 'Pharmacy', query: 'pharmacy', icon: 'local_pharmacy'),
    SearchCategory(label: 'Government', query: 'government office', icon: 'account_balance'),
    SearchCategory(label: 'Tourist Spot', query: 'tourist spot', icon: 'attractions'),
    SearchCategory(label: 'University', query: 'university', icon: 'school'),
    SearchCategory(label: 'Gas Station', query: 'gas station', icon: 'local_gas_station'),
    SearchCategory(label: 'Barangay Hall', query: 'barangay hall', icon: 'home_work'),
  ];
}
