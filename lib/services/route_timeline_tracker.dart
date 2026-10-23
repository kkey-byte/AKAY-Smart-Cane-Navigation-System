import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/route_plan.dart';
import '../models/route_timeline_entry.dart';
import 'navigator_location_service.dart';

/// Records meaningful location changes during active navigation.
/// Ready for GPS + reverse geocoding and Firebase persistence.
class RouteTimelineTracker extends ChangeNotifier {
  RouteTimelineTracker._();

  static final RouteTimelineTracker instance = RouteTimelineTracker._();

  static const _minDistanceMeters = 30.0;

  final List<RouteTimelineEntry> entries = [];

  bool isTracking = false;
  String? _lastAddress;
  LatLng? _lastEntryPosition;
  MapPlace? _destination;

  MapPlace? get activeDestination => _destination;

  void startTracking(MapPlace destination) {
    stopTracking(saveHistory: false);
    _destination = destination;
    isTracking = true;
    _lastAddress = null;

    entries.clear();
    _lastEntryPosition = NavigatorLocationService.instance.livePosition;
    final startAddress = NavigatorLocationService.instance.address;
    _appendEntry(startAddress, force: true);

    notifyListeners();
  }

  void stopTracking({bool saveHistory = true}) {
    isTracking = false;
    _destination = null;
    _lastAddress = null;
    _lastEntryPosition = null;

    if (saveHistory) {
      // TODO: Persist entries to Firebase for caregiver reports.
    }

    notifyListeners();
  }

  /// Called when GPS + reverse geocoding detects a new meaningful stop.
  void onLocationUpdate({
    required String geocodedAddress,
    required double distanceMovedMeters,
    LatLng? location,
  }) {
    if (!isTracking) return;

    final point = location ?? NavigatorLocationService.instance.livePosition;
    final previous = _lastEntryPosition;
    final distance = point != null && previous != null
        ? Geolocator.distanceBetween(
            previous.latitude,
            previous.longitude,
            point.latitude,
            point.longitude,
          )
        : distanceMovedMeters;
    final address = geocodedAddress.trim();
    final sameAddress =
        address.toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ==
        _lastAddress?.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (entries.isNotEmpty && (distance < _minDistanceMeters || sameAddress)) {
      return;
    }
    if (address.isEmpty) return;
    _lastEntryPosition = point;
    _appendEntry(address);
  }

  void markDestinationArrived() => _completeRoute();

  void _completeRoute() {
    final destination = _destination;
    if (destination == null) return;

    _appendEntry(
      '${destination.name}, ${destination.address} (Arrived)',
      isArrived: true,
      force: true,
    );

    isTracking = false;
    notifyListeners();

    // TODO: Upload completed route timeline to Firebase.
  }

  void _appendEntry(
    String address, {
    bool isArrived = false,
    bool force = false,
  }) {
    if (!force && _lastAddress == address) return;

    _lastAddress = address;
    entries.add(
      RouteTimelineEntry(
        address: address,
        timestamp: DateTime.now(),
        isArrived: isArrived,
      ),
    );
    notifyListeners();
  }

  void reset() {
    stopTracking(saveHistory: false);
    entries.clear();
    notifyListeners();
  }
}
