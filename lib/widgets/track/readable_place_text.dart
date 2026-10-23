import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/map_place_service.dart';

/// Presentation-only reverse lookup; never changes a route or GPS position.
class ReadablePlaceText extends StatelessWidget {
  const ReadablePlaceText(
    this.address, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.suffix = '',
  });

  final String address;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final String suffix;

  static final _cache = <String, Future<String?>>{};
  static final _coordinates = RegExp(
    r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$',
  );

  static LatLng? coordinates(String value) {
    final match = _coordinates.firstMatch(value);
    if (match == null) return null;
    final lat = double.parse(match[1]!);
    final lon = double.parse(match[2]!);
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return LatLng(lat, lon);
  }

  static Future<String?> _lookup(LatLng point) async {
    try {
      final place = await MapPlaceService.instance.placeFromCoordinates(point);
      final address = place.address.trim();
      if (address.isNotEmpty && coordinates(address) == null) return address;
    } catch (_) {
      // Keep the supplied coordinates when the existing service cannot resolve.
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final point = coordinates(address);
    Widget label(String value) => Text(
      '$value$suffix',
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
    if (point == null) return label(address);
    // Share lookups across the planner, details, and timeline; absorb GPS jitter.
    final key =
        '${point.latitude.toStringAsFixed(3)},${point.longitude.toStringAsFixed(3)}';
    if (_cache.length >= 128 && !_cache.containsKey(key)) {
      _cache.remove(_cache.keys.first);
    }
    final result = _cache.putIfAbsent(key, () => _lookup(point));
    return FutureBuilder<String?>(
      key: ValueKey(key),
      future: result,
      builder: (_, snapshot) => label(snapshot.data ?? address),
    );
  }
}
