import 'dart:async';

import 'package:app_mobile/services/navigator_location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class DeviceLocationFake extends GeolocatorPlatform {
  bool denied = true;
  int currentRequests = 0;
  int cachedRequests = 0;
  final updates = StreamController<Position>.broadcast();

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => denied
      ? LocationPermission.deniedForever
      : LocationPermission.whileInUse;

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) {
    cachedRequests++;
    throw UnsupportedError('No cached location on web');
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    currentRequests++;
    return Position(
      latitude: 14.5995,
      longitude: 120.9842,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      updates.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('permission recovery uses current device fix without cached-location API', () async {
    final original = GeolocatorPlatform.instance;
    final fake = DeviceLocationFake();
    GeolocatorPlatform.instance = fake;
    final service = NavigatorLocationService.instance;
    try {
      await service.startTracking();
      expect(service.permissionDenied, isTrue);
      expect(service.livePosition, isNull);
      expect(fake.currentRequests, 0);

      fake.denied = false;
      await service.startTracking();
      expect(fake.cachedRequests, 0);
      expect(fake.currentRequests, 1);
      expect(service.permissionDenied, isFalse);
      expect(service.livePosition!.latitude, 14.5995);
      expect(service.livePosition!.longitude, 120.9842);
      expect(service.isTracking, isTrue);
      expect(service.errorMessage, isNull);
    } finally {
      service.stopTracking();
      await fake.updates.close();
      GeolocatorPlatform.instance = original;
    }
  });
}
