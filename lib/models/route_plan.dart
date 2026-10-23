import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'linked_navigator.dart';
import '../utils/destination_labels.dart';

/// A place with coordinates — ready for Google Places API integration.
class MapPlace {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? distance;
  final bool isSaved;
  final String? category;
  final String? walkingTime;
  final String? source;
  final bool isAccessible;
  final int? distanceMeters;

  const MapPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.distance,
    this.isSaved = false,
    this.category,
    this.walkingTime,
    this.source,
    this.isAccessible = false,
    this.distanceMeters,
  });

  bool get hasValidCoordinates =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  LatLng get latLng => LatLng(latitude, longitude);

  String get displayName => DestinationLabels.name(name, address);
  String get shortAddress => DestinationLabels.shortAddress(address, name);

  MapPlace copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? distance,
    String? category,
    String? walkingTime,
    String? source,
    bool? isAccessible,
    int? distanceMeters,
  }) {
    return MapPlace(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distance: distance ?? this.distance,
      isSaved: isSaved,
      category: category ?? this.category,
      walkingTime: walkingTime ?? this.walkingTime,
      source: source ?? this.source,
      isAccessible: isAccessible ?? this.isAccessible,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }
}

/// Result returned from Route Planner to Track Page.
class RoutePlanResult {
  final LinkedNavigator navigator;
  final MapPlace destination;
  final String estimatedTime;
  final String estimatedDistance;
  final String currentSpeed;
  final String navigationStatus;
  final List<LatLng> polylinePoints;
  final DateTime tripStartedAt;

  /// Real OSRM / routing turn instructions for the Turn-by-Turn panel.
  final List<RouteTurnInstruction> turnInstructions;

  const RoutePlanResult({
    required this.navigator,
    required this.destination,
    required this.estimatedTime,
    required this.estimatedDistance,
    required this.currentSpeed,
    required this.navigationStatus,
    required this.polylinePoints,
    required this.tripStartedAt,
    this.turnInstructions = const [],
  });

  String get formattedTripStarted {
    final hour = tripStartedAt.hour > 12
        ? tripStartedAt.hour - 12
        : (tripStartedAt.hour == 0 ? 12 : tripStartedAt.hour);
    final period = tripStartedAt.hour >= 12 ? 'PM' : 'AM';
    final minute = tripStartedAt.minute.toStringAsFixed(0).padLeft(2, '0');
    return '$hour:$minute $period';
  }
}

/// One guidance step from the routing engine (OSRM).
class RouteTurnInstruction {
  const RouteTurnInstruction({
    required this.instruction,
    this.detail = '',
    this.maneuverType = 'turn',
    this.modifier = '',
    this.isNext = false,
  });

  final String instruction;
  final String detail;
  final String maneuverType;
  final String modifier;
  final bool isNext;

  RouteTurnInstruction copyWith({bool? isNext}) {
    return RouteTurnInstruction(
      instruction: instruction,
      detail: detail,
      maneuverType: maneuverType,
      modifier: modifier,
      isNext: isNext ?? this.isNext,
    );
  }
}

/// Default map anchor — Panabo City, Davao del Norte.
class GabayMapDefaults {
  GabayMapDefaults._();

  static const LatLng mapCenter = LatLng(7.3081, 125.6842);
  static const double defaultZoom = 14.5;

  static const LatLng caregiverLocation = LatLng(7.3102, 125.6818);
  static const LatLng visuallyImpairedLocation = LatLng(7.3064, 125.6865);

  static const String caregiverAddress =
      'Rizal Street, Panabo City, Davao del Norte';
  static const String navigatorAddress =
      'Quezon Street, Panabo City, Davao del Norte';

  /// Straight fallback only when routing fails — not used for normal navigation.
  static List<LatLng> mockPolyline(LatLng origin, LatLng destination) {
    return [origin, destination];
  }

  /// Mock ETA — replace with Directions API duration.
  static String mockEta(LatLng origin, LatLng destination) {
    final km = _distanceKm(origin, destination);
    final minutes = (km / 4.5 * 60).round().clamp(3, 120);
    return '$minutes min';
  }

  static String mockDistance(LatLng origin, LatLng destination) {
    final km = _distanceKm(origin, destination);
    return km >= 1 ? '${km.toStringAsFixed(1)} km' : '${(km * 1000).round()} m';
  }

  static double _distanceKm(LatLng a, LatLng b) {
    const earthRadius = 6371.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);

    final h =
        pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLng / 2), 2);
    return earthRadius * 2 * asin(sqrt(h));
  }

  static double _toRad(double deg) => deg * pi / 180;
}
