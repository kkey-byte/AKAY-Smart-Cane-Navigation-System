import 'package:google_maps_flutter/google_maps_flutter.dart';

enum GabayMapMarkerKind {
  routeStart,
  routeProgress,
  destination,
  navigator,
  caregiver,
  generic,
}

class GabayMapMarkerData {
  const GabayMapMarkerData({
    required this.id,
    required this.position,
    required this.kind,
    this.title,
    this.snippet,
    this.zIndex = 1,
    this.hue,
  });

  final String id;
  final LatLng position;
  final GabayMapMarkerKind kind;
  final String? title;
  final String? snippet;
  final int zIndex;
  final double? hue;
}
