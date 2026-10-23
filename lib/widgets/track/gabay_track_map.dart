import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as ll;

import '../../utils/gabay_map_rendering.dart';
import 'gabay_map_marker.dart';
import 'gabay_map_marker_widgets.dart';

class TrackMapController {
  gmaps.GoogleMapController? _googleController;
  MapController? _flutterController;

  bool get usesGoogleMaps => _googleController != null;
  bool get isReady => _googleController != null || _flutterController != null;

  void attachGoogle(gmaps.GoogleMapController controller) {
    _googleController = controller;
    _flutterController = null;
  }

  void attachFlutter(MapController controller) {
    _flutterController = controller;
    _googleController = null;
  }

  Future<void> zoomIn() async {
    if (_googleController != null) {
      await _googleController!.animateCamera(gmaps.CameraUpdate.zoomIn());
      return;
    }
    final controller = _flutterController;
    if (controller == null) return;
    controller.move(controller.camera.center, controller.camera.zoom + 1);
  }

  Future<void> zoomOut() async {
    if (_googleController != null) {
      await _googleController!.animateCamera(gmaps.CameraUpdate.zoomOut());
      return;
    }
    final controller = _flutterController;
    if (controller == null) return;
    controller.move(controller.camera.center, controller.camera.zoom - 1);
  }

  Future<void> animateToLatLng(gmaps.LatLng target, {double zoom = 16}) async {
    if (_googleController != null) {
      await _googleController!.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(target, zoom),
      );
      return;
    }
    final controller = _flutterController;
    if (controller == null) return;
    controller.move(_toLatLong(target), zoom);
  }

  Future<void> fitBounds(
    List<gmaps.LatLng> points, {
    double padding = 80,
  }) async {
    if (points.isEmpty) return;
    if (points.length == 1 || points.every((point) => point == points.first)) {
      await animateToLatLng(points.first);
      return;
    }

    if (_googleController != null) {
      final bounds = _googleBoundsFromPoints(points);
      await _googleController!.animateCamera(
        gmaps.CameraUpdate.newLatLngBounds(bounds, padding),
      );
      return;
    }

    final controller = _flutterController;
    if (controller == null) return;

    final latLngPoints = points.map(_toLatLong).toList();
    controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(latLngPoints),
        padding: EdgeInsets.all(padding),
      ),
    );
  }

  static ll.LatLng _toLatLong(gmaps.LatLng point) {
    return ll.LatLng(point.latitude, point.longitude);
  }

  static gmaps.LatLngBounds _googleBoundsFromPoints(List<gmaps.LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    return gmaps.LatLngBounds(
      southwest: gmaps.LatLng(minLat, minLng),
      northeast: gmaps.LatLng(maxLat, maxLng),
    );
  }
}

/// Live OpenStreetMap track view with automatic camera follow.
class GabayTrackMap extends StatefulWidget {
  const GabayTrackMap({
    super.key,
    required this.initialCamera,
    required this.markers,
    required this.routePoints,
    this.breadcrumbPoints = const [],
    required this.padding,
    required this.onControllerReady,
    this.googleMarkerIcons,

    /// When set (and [followUser] is true), the camera tracks this point.
    this.followTarget,
    this.followUser = false,
    this.followZoom = 16,

    /// Tap/long-press to pin a destination on the map.
    this.onMapTap,
  });

  final gmaps.CameraPosition initialCamera;
  final List<GabayMapMarkerData> markers;
  final List<gmaps.LatLng> routePoints;
  final List<gmaps.LatLng> breadcrumbPoints;
  final EdgeInsets padding;
  final ValueChanged<TrackMapController> onControllerReady;
  final GabayMapMarkerIcons? googleMarkerIcons;
  final gmaps.LatLng? followTarget;
  final bool followUser;
  final double followZoom;
  final ValueChanged<gmaps.LatLng>? onMapTap;

  @override
  State<GabayTrackMap> createState() => _GabayTrackMapState();
}

class _GabayTrackMapState extends State<GabayTrackMap> {
  final _trackController = TrackMapController();
  final _flutterMapController = MapController();
  bool _flutterMapReady = false;
  gmaps.LatLng? _lastFollowed;

  @override
  void didUpdateWidget(covariant GabayTrackMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFollowCamera();
  }

  void _syncFollowCamera() {
    if (!widget.followUser) return;
    final target = widget.followTarget;
    if (target == null || !_flutterMapReady) return;

    // Skip tiny jitter moves (< ~2 m) to keep the map smooth.
    if (_lastFollowed != null) {
      final dLat = (target.latitude - _lastFollowed!.latitude).abs();
      final dLng = (target.longitude - _lastFollowed!.longitude).abs();
      if (dLat < 0.00002 && dLng < 0.00002) return;
    }

    _lastFollowed = target;
    _flutterMapController.move(
      ll.LatLng(target.latitude, target.longitude),
      widget.followZoom,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Soft map-tint background so the screen never looks blank white/grey
    // while tiles are downloading.
    return ColoredBox(
      color: const Color(0xFFDCEDE4),
      child: _buildOpenStreetMap(context),
    );
  }

  Widget _buildOpenStreetMap(BuildContext context) {
    final centerTarget = widget.followTarget ?? widget.initialCamera.target;
    final center = ll.LatLng(centerTarget.latitude, centerTarget.longitude);

    return FlutterMap(
      mapController: _flutterMapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: widget.followUser
            ? widget.followZoom
            : widget.initialCamera.zoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onTap: widget.onMapTap == null
            ? null
            : (tapPosition, point) {
                widget.onMapTap!(gmaps.LatLng(point.latitude, point.longitude));
              },
        onLongPress: widget.onMapTap == null
            ? null
            : (tapPosition, point) {
                widget.onMapTap!(gmaps.LatLng(point.latitude, point.longitude));
              },
        onMapReady: () {
          if (_flutterMapReady) return;
          _flutterMapReady = true;
          _trackController.attachFlutter(_flutterMapController);
          widget.onControllerReady(_trackController);
          // Jump to live GPS as soon as the map is ready.
          _syncFollowCamera();
        },
      ),
      children: [
        TileLayer(
          // Standard OSM tiles do not require a CARTO or Google Maps key.
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'AKAY.app_mobile',
          maxNativeZoom: 19,
        ),
        if (widget.routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.routePoints.map(_toLatLong).toList(),
                color: GabayMapRendering.routeAccent.withValues(alpha: 0.22),
                strokeWidth: 18,
              ),
              Polyline(
                points: widget.routePoints.map(_toLatLong).toList(),
                color: GabayMapRendering.routeAccent,
                strokeWidth: 5,
              ),
            ],
          ),
        if (widget.breadcrumbPoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.breadcrumbPoints.map(_toLatLong).toList(),
                color: Theme.of(context).colorScheme.tertiary,
                strokeWidth: 5,
              ),
            ],
          ),
        MarkerLayer(
          markers: widget.markers
              .map(
                (marker) => Marker(
                  point: _toLatLong(marker.position),
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  child: gabayMarkerWidgetForKind(
                    marker.kind,
                    genericColor: marker.hue == null
                        ? null
                        : HSVColor.fromAHSV(
                            1,
                            marker.hue!,
                            0.75,
                            0.9,
                          ).toColor(),
                  ),
                ),
              )
              .toList(),
        ),
        // Keep the credit above the destination/ETA panels owned by the page.
        Positioned(
          left: widget.padding.left + 8,
          bottom: widget.padding.bottom + 8,
          child: const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xEEFFFFFF)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(
                '© OpenStreetMap contributors\n'
                'openstreetmap.org/copyright',
                style: TextStyle(color: Color(0xFF222222), fontSize: 10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  ll.LatLng _toLatLong(gmaps.LatLng point) {
    return ll.LatLng(point.latitude, point.longitude);
  }
}
