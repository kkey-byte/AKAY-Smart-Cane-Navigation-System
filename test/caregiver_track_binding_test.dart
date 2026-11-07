import 'dart:async';

import 'package:app_mobile/models/dashboard_snapshot.dart';
import 'package:app_mobile/pages/screens/track_page.dart';
import 'package:app_mobile/services/navigator_location_service.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/models/route_plan.dart';
import 'package:app_mobile/widgets/track/gabay_track_map.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'dashboard_live_test.dart' show FakeDashboard;

class MonitoringUser extends Fake implements User {
  @override
  String get uid => 'synthetic-caregiver';
}

class MonitoringAuth extends Fake implements FirebaseAuth {
  final updates = StreamController<User?>.broadcast();
  @override
  Stream<User?> authStateChanges() => updates.stream;
}

class LocalGps extends GeolocatorPlatform {
  final updates = StreamController<Position>.broadcast();
  int checks = 0;
  @override
  Future<bool> isLocationServiceEnabled() async {
    checks++;
    return true;
  }

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => fix(1, 2);
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      updates.stream;
}

Position fix(double latitude, double longitude) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MonitoringAuth auth;
  late FakeDashboard dashboard;
  late StreamController<Map<String, String>> links;
  late LocalGps gps;
  late GeolocatorPlatform oldGps;

  setUp(() {
    auth = MonitoringAuth();
    dashboard = FakeDashboard();
    links = StreamController<Map<String, String>>.broadcast();
    oldGps = GeolocatorPlatform.instance;
    gps = LocalGps();
    GeolocatorPlatform.instance = gps;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (_) async => 1,
        );
  });

  tearDown(() async {
    NavigatorLocationService.instance.stopTracking(clearLocation: true);
    GeolocatorPlatform.instance = oldGps;
    await auth.updates.close();
    await links.close();
    await dashboard.close();
    await gps.updates.close();
  });

  DashboardSnapshot remote(
    String uid, {
    LatLng? position,
    List<LatLng> points = const [],
  }) => DashboardSnapshot(
    uid: uid,
    name: uid,
    position: position,
    locationTime: position == null ? null : DateTime.now(),
    points: points,
  );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: TrackPage(
          firebaseAuth: auth,
          dashboardService: dashboard,
          watchSharedNavigators: (_) => links.stream,
        ),
      ),
    );
    auth.updates.add(MonitoringUser());
    await tester.pump();
    links.add({'navigator-a': 'Navigator A', 'navigator-b': 'Navigator B'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  GabayTrackMap map(WidgetTester tester) =>
      tester.widget(find.byType(GabayTrackMap));
  void expectCamera(WidgetTester tester, LatLng expected) {
    final camera = MapCamera.of(tester.element(find.byType(TileLayer)));
    expect(camera.center.latitude, closeTo(expected.latitude, .00001));
    expect(camera.center.longitude, closeTo(expected.longitude, .00001));
  }

  testWidgets(
    'monitor follows selected remote GPS and history, ignoring local fixes',
    (tester) async {
      await NavigatorLocationService.instance.startTracking();
      final initialChecks = gps.checks;
      const a = LatLng(10, 20), b = LatLng(30, 40);
      const aPath = [LatLng(9.99, 20), a], bPath = [LatLng(29.99, 40), b];
      dashboard.values['navigator-a'] = remote(
        'navigator-a',
        position: a,
        points: aPath,
      );
      dashboard.values['navigator-b'] = remote(
        'navigator-b',
        position: b,
        points: bPath,
      );
      await open(tester);
      expect(gps.checks, initialChecks);
      expect(map(tester).initialCamera.target, a);
      expect(map(tester).followTarget, a);
      expect(map(tester).breadcrumbPoints, aPath);
      expect(map(tester).markers.map((m) => m.id), ['navigator_navigator-a']);
      expectCamera(tester, a);

      gps.updates.add(fix(3, 4));
      await tester.pump();
      expectCamera(tester, a);
      const a2 = LatLng(10.01, 20.01);
      dashboard.updates['navigator-a']!.add(
        remote('navigator-a', position: a2, points: [...aPath, a2]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(map(tester).followTarget, a2);
      expectCamera(tester, a2);

      await tester.tap(find.text('Navigator A').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Navigator B').last);
      await tester.pumpAndSettle();
      expect(map(tester).followTarget, b);
      expect(map(tester).breadcrumbPoints, bPath);
      expectCamera(tester, b);
      dashboard.updates['navigator-a']!.add(
        remote('navigator-a', position: const LatLng(11, 21)),
      );
      await tester.pump();
      expectCamera(tester, b);
      await tester.tap(find.text('Navigator B').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close navigator selector'));
      await tester.pumpAndSettle();
      expect(map(tester).markers.map((m) => m.id).toSet(), {
        'navigator_navigator-a',
        'navigator_navigator-b',
      });
      final bounds = MapCamera.of(
        tester.element(find.byType(TileLayer)),
      ).visibleBounds;
      expect(bounds.contains(const ll.LatLng(3, 4)), isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(links.hasListener, isFalse);
      expect(
        dashboard.updates.values.every((stream) => !stream.hasListener),
        isTrue,
      );
    },
  );

  testWidgets('history-only and unavailable records never use caregiver GPS', (
    tester,
  ) async {
    await NavigatorLocationService.instance.startTracking();
    const path = [LatLng(10, 20), LatLng(10.01, 20.01)];
    dashboard.values['navigator-a'] = remote('navigator-a', points: path);
    await open(tester);
    expect(map(tester).breadcrumbPoints, path);
    expect(map(tester).initialCamera.target, path.last);
    expectCamera(tester, path.last);
    expect(map(tester).followTarget, isNull);
    dashboard.updates['navigator-a']!.add(
      remote('wrong-owner', position: const LatLng(1, 2)),
    );
    await tester.pump();
    expect(map(tester).markers, isEmpty);
    expect(map(tester).breadcrumbPoints, isEmpty);
    expect(map(tester).initialCamera.target, GabayMapDefaults.mapCenter);
    expect(map(tester).followTarget, isNull);
    links.add({});
    await tester.pump();
    expect(map(tester).markers, isEmpty);
    expect(
      dashboard.updates.values.every((stream) => !stream.hasListener),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('caregiver monitoring does not request local GPS access', (
    tester,
  ) async {
    await open(tester);
    expect(gps.checks, 0);
    expect(map(tester).initialCamera.target, GabayMapDefaults.mapCenter);
    expect(map(tester).followTarget, isNull);
    expect(map(tester).markers, isEmpty);
    auth.updates.add(null);
    await tester.pump();
    expect(map(tester).breadcrumbPoints, isEmpty);
    expect(
      dashboard.updates.values.every((stream) => !stream.hasListener),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
