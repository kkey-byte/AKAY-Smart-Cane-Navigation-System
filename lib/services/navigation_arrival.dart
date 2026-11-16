import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Match the assigned-destination backend's 35 m / fresh accurate GPS contract.
bool hasArrivedAtDestination({
  required LatLng location,
  required LatLng destination,
  required double accuracy,
  required DateTime sampledAt,
  required DateTime now,
}) {
  if (!accuracy.isFinite ||
      accuracy < 0 ||
      accuracy > 35 ||
      now.difference(sampledAt) > const Duration(seconds: 45) ||
      sampledAt.difference(now) > const Duration(seconds: 30)) {
    return false;
  }
  return Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        destination.latitude,
        destination.longitude,
      ) <=
      35;
}
