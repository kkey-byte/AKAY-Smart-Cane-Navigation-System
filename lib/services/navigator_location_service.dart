import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'route_timeline_tracker.dart';

/// Live GPS + reverse geocoding for the logged-in visually impaired navigator.
///
/// Never silently pins the user to a hardcoded city — until a real GPS fix
/// arrives, [hasLiveFix] is false and callers should wait / show locating UI.
class NavigatorLocationService extends ChangeNotifier {
  NavigatorLocationService._();

  static final NavigatorLocationService instance = NavigatorLocationService._();

  static LocationSettings get _streamSettings {
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 2),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
  }

  static LocationSettings get _initialFixSettings {
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      timeLimit: Duration(seconds: 25),
    );
  }

  StreamSubscription<Position>? _positionSub;
  LatLng? _position;
  Position? _lastPosition;
  String _address = 'Locating you…';
  bool isLoading = false;
  bool permissionDenied = false;
  String? errorMessage;

  LatLng? _lastGeocodePoint;
  DateTime? _lastGeocodeAt;
  int _retryCount = 0;

  /// Live GPS only. Null until the device reports a real fix.
  LatLng? get livePosition => _position;

  /// Full Geolocator fix (speed / heading / accuracy) for Firebase live_location.
  Position? get lastPosition => _lastPosition;

  /// Ground speed in m/s (0 if unavailable).
  double get speedMetersPerSecond =>
      (_lastPosition?.speed ?? 0).isFinite && (_lastPosition?.speed ?? 0) >= 0
      ? _lastPosition!.speed
      : 0;

  /// Heading in degrees (0–360). Null if unavailable.
  double? get headingDegrees {
    final h = _lastPosition?.heading;
    if (h == null || !h.isFinite || h < 0) return null;
    return h;
  }

  /// Horizontal accuracy in meters.
  double? get accuracyMeters {
    final a = _lastPosition?.accuracy;
    if (a == null || !a.isFinite || a < 0) return null;
    return a;
  }

  /// Same as [livePosition], or a temporary (0,0) sentinel — prefer [livePosition].
  LatLng get location {
    final live = _position;
    if (live != null) return live;
    // Neutral ocean coordinate — NOT Panabo. Callers should check [hasLiveFix].
    return const LatLng(0, 0);
  }

  String get address => _address;

  bool get hasLiveFix => _position != null;

  bool get isTracking => _positionSub != null;

  Future<void> startTracking() async {
    // Allow restart if we never got a fix.
    if (isLoading || (_positionSub != null && hasLiveFix)) return;

    await _positionSub?.cancel();
    _positionSub = null;

    isLoading = true;
    permissionDenied = false;
    errorMessage = null;
    notifyListeners();

    final granted = await _ensurePermission();
    if (!granted) {
      isLoading = false;
      permissionDenied = true;
      errorMessage ??=
          'Location permission is required. Enable GPS and allow location access.';
      notifyListeners();
      return;
    }

    try {
      // Request this device's current fix. Cached positions can be stale,
      // and getLastKnownPosition is not supported by the web implementation.
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: _initialFixSettings,
      );
      await _applyPosition(initial);

      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: _streamSettings,
          ).listen(
            (position) => unawaited(_applyPosition(position)),
            onError: (Object error) {
              debugPrint('GPS stream error: $error');
              errorMessage = 'Unable to read GPS location.';
              isLoading = false;
              notifyListeners();
              _scheduleRetry();
            },
          );
      _retryCount = 0;
    } on TimeoutException {
      errorMessage =
          'Location timed out. Move outdoors with a clear sky view and try again.';
      _scheduleRetry();
    } catch (e) {
      debugPrint('GPS start error: $e');
      errorMessage = 'Unable to read GPS location: $e';
      _scheduleRetry();
    }

    isLoading = false;
    notifyListeners();
  }

  void _scheduleRetry() {
    if (_retryCount >= 3) return;
    _retryCount++;
    Future<void>.delayed(Duration(seconds: 2 * _retryCount), () {
      if (_positionSub == null || !hasLiveFix) {
        unawaited(startTracking());
      }
    });
  }

  void stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshCurrentLocation() async {
    if (isLoading) return;
    permissionDenied = false;
    final granted = await _ensurePermission();
    if (!granted) {
      permissionDenied = true;
      errorMessage = 'Location permission is required for live tracking.';
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _initialFixSettings,
      );
      await _applyPosition(position);
    } on TimeoutException {
      errorMessage = 'Location timed out. Please try again outdoors.';
    } catch (e) {
      errorMessage = 'Unable to read GPS location.';
      debugPrint('refreshCurrentLocation: $e');
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      errorMessage = 'GPS is turned off. Please enable location services.';
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      errorMessage =
          'Location permission permanently denied. Enable it in system Settings.';
      return false;
    }

    if (permission == LocationPermission.denied) {
      errorMessage = 'Location permission denied.';
      return false;
    }

    return true;
  }

  Future<void> _applyPosition(Position position, {bool geocode = true}) async {
    final previous = _position;
    _lastPosition = position;
    _position = LatLng(position.latitude, position.longitude);

    final movedMeters = previous == null
        ? 0.0
        : Geolocator.distanceBetween(
            previous.latitude,
            previous.longitude,
            _position!.latitude,
            _position!.longitude,
          );

    // Publish the coordinate immediately; address lookup must not delay the map.
    _address = _coordinateFallback(_position!);
    isLoading = false;
    errorMessage = null;
    notifyListeners();

    if (geocode && !kIsWeb) {
      _address = await _resolveAddress(_position!, movedMeters);
    } else {
      _address = _coordinateFallback(_position!);
    }

    if (RouteTimelineTracker.instance.isTracking) {
      RouteTimelineTracker.instance.onLocationUpdate(
        geocodedAddress: _address,
        distanceMovedMeters: movedMeters,
      );

      final destination = RouteTimelineTracker.instance.activeDestination;
      if (destination != null) {
        final distanceToDestination = Geolocator.distanceBetween(
          _position!.latitude,
          _position!.longitude,
          destination.latitude,
          destination.longitude,
        );
        if (distanceToDestination <= 35) {
          RouteTimelineTracker.instance.markDestinationArrived();
        }
      }
    }

    isLoading = false;
    errorMessage = null;
    notifyListeners();
  }

  Future<String> _resolveAddress(LatLng point, double movedMeters) async {
    final now = DateTime.now();
    if (_lastGeocodePoint != null &&
        _lastGeocodeAt != null &&
        movedMeters < 20 &&
        now.difference(_lastGeocodeAt!) < const Duration(seconds: 20) &&
        !_address.startsWith('Locating')) {
      return _address;
    }

    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );

      if (placemarks.isEmpty) {
        return _coordinateFallback(point);
      }

      _lastGeocodePoint = point;
      _lastGeocodeAt = now;
      return _formatPlacemark(placemarks.first, point);
    } catch (_) {
      return _coordinateFallback(point);
    }
  }

  String _formatPlacemark(Placemark place, LatLng point) {
    final parts = <String>[
      if (place.street != null && place.street!.trim().isNotEmpty)
        place.street!.trim(),
      if (place.subLocality != null && place.subLocality!.trim().isNotEmpty)
        place.subLocality!.trim(),
      if (place.locality != null && place.locality!.trim().isNotEmpty)
        place.locality!.trim(),
      if (place.administrativeArea != null &&
          place.administrativeArea!.trim().isNotEmpty)
        place.administrativeArea!.trim(),
    ];

    if (parts.isEmpty) {
      return _coordinateFallback(point);
    }

    return parts.join(', ');
  }

  String _coordinateFallback(LatLng point) {
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }
}
