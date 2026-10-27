import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'route_timeline_tracker.dart';
import 'vi_navigation_session.dart';

/// Live GPS + reverse geocoding for the logged-in visually impaired navigator.
///
/// Never silently pins the user to a hardcoded city — until a real GPS fix
/// arrives, [hasLiveFix] is false and callers should wait / show locating UI.
class NavigatorLocationService extends ChangeNotifier {
  NavigatorLocationService._() {
    ViNavigationSession.instance.addListener(_onNavigationModeChanged);
  }

  static final NavigatorLocationService instance = NavigatorLocationService._();
  static bool _backgroundRecording = false;
  bool _lastNavigationMode = false;
  static bool get _allDayMode =>
      _backgroundRecording && !ViNavigationSession.instance.isNavigating;

  void _onNavigationModeChanged() {
    final navigating = ViNavigationSession.instance.isNavigating;
    if (_lastNavigationMode == navigating) return;
    _lastNavigationMode = navigating;
    if (_backgroundRecording && _positionSub != null) {
      unawaited(_restartForSettings());
    }
  }

  Future<void> _restartForSettings() async {
    final subscription = _positionSub;
    _positionSub = null;
    await subscription?.cancel();
    if (_trackingRequested) await startTracking();
  }

  static LocationSettings get _streamSettings {
    if (kIsWeb) {
      return LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _backgroundRecording ? 1 : 5,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: _allDayMode
            ? LocationAccuracy.high
            : LocationAccuracy.bestForNavigation,
        distanceFilter: _backgroundRecording ? 1 : 5,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: _backgroundRecording
            ? const ForegroundNotificationConfig(
                notificationTitle: 'AKAY is recording your track',
                notificationText:
                    'Your shared caregivers can monitor your daily path. Open My tracks to pause.',
                enableWakeLock: true,
              )
            : null,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: _allDayMode
            ? LocationAccuracy.high
            : LocationAccuracy.bestForNavigation,
        distanceFilter: _backgroundRecording ? 1 : 5,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: _backgroundRecording,
        showBackgroundLocationIndicator: _backgroundRecording,
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
  Timer? _retryTimer;
  bool _trackingRequested = false;
  int _locationGeneration = 0;

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

  Future<void> setBackgroundRecording(bool enabled) async {
    if (!enabled && !ViNavigationSession.instance.isNavigating) {
      _backgroundRecording = false;
      stopTracking();
      return;
    }
    if (_backgroundRecording == enabled) return;
    _backgroundRecording = enabled;
    await _positionSub?.cancel();
    _positionSub = null;
    if (_trackingRequested) await startTracking();
  }

  Future<void> startTracking({bool requestPermission = true}) async {
    final generation = _locationGeneration;
    _trackingRequested = true;
    // Allow restart if we never got a fix.
    if (isLoading || (_positionSub != null && hasLiveFix)) return;

    await _positionSub?.cancel();
    _positionSub = null;

    isLoading = true;
    permissionDenied = false;
    errorMessage = null;
    notifyListeners();

    final granted = await _ensurePermission(
      requestPermission: requestPermission,
    );
    if (!_trackingRequested || generation != _locationGeneration) return;
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
      final recent = _lastPosition;
      final initial =
          recent != null &&
              DateTime.now().difference(recent.timestamp).abs() <=
                  const Duration(seconds: 30)
          ? recent
          : await Geolocator.getCurrentPosition(
              locationSettings: _initialFixSettings,
            );
      if (!_trackingRequested || generation != _locationGeneration) return;
      await _applyPosition(initial);
      if (!_trackingRequested || generation != _locationGeneration) return;

      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: _streamSettings,
          ).listen(
            (position) {
              if (_trackingRequested && generation == _locationGeneration) {
                unawaited(_applyPosition(position));
              }
            },
            onError: (Object error) {
              final failedSubscription = _positionSub;
              _positionSub = null;
              unawaited(failedSubscription?.cancel());
              debugPrint('GPS stream unavailable.');
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
      debugPrint('GPS start unavailable.');
      errorMessage = 'Unable to read GPS location.';
      _scheduleRetry();
    }

    isLoading = false;
    notifyListeners();
  }

  void _scheduleRetry() {
    final generation = _locationGeneration;
    if (!_trackingRequested || _retryCount >= 3) return;
    _retryCount++;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: 2 * _retryCount), () {
      if (!_trackingRequested || generation != _locationGeneration) return;
      if (_positionSub == null || !hasLiveFix) {
        unawaited(startTracking());
      }
    });
  }

  void stopTracking({bool clearLocation = false}) {
    _locationGeneration++;
    if (clearLocation) {
      _position = null;
      _lastPosition = null;
      _address = 'Location unavailable';
      _lastGeocodePoint = null;
      _lastGeocodeAt = null;
    }
    _trackingRequested = false;
    _retryTimer?.cancel();
    _positionSub?.cancel();
    _positionSub = null;
    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshCurrentLocation({bool requestPermission = true}) async {
    final generation = _locationGeneration;
    if (isLoading) return;
    permissionDenied = false;
    final granted = await _ensurePermission(
      requestPermission: requestPermission,
    );
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
      if (generation != _locationGeneration) return;
      await _applyPosition(position);
    } on TimeoutException {
      errorMessage = 'Location timed out. Please try again outdoors.';
    } catch (e) {
      errorMessage = 'Unable to read GPS location.';
      debugPrint('Current GPS location unavailable.');
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> _ensurePermission({bool requestPermission = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      errorMessage = 'GPS is turned off. Please enable location services.';
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
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
    final generation = _locationGeneration;
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
      final address = await _resolveAddress(_position!, movedMeters);
      if (generation != _locationGeneration) return;
      _address = address;
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
