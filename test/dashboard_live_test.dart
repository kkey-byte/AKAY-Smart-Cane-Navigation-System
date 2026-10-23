import 'dart:async';
import 'package:app_mobile/models/dashboard_snapshot.dart';
import 'package:app_mobile/models/pairing.dart';
import 'package:app_mobile/services/app_session_service.dart';
import 'package:app_mobile/services/dashboard_service.dart';
import 'package:app_mobile/services/map_place_service.dart';
import 'package:app_mobile/models/user_role.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/dashboard_widgets/dashboard_navigation_view.dart';
import 'package:app_mobile/widgets/dashboard_widgets/dashboard_live_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'pairing_security_test.dart' show FakePairing;

class FakeDashboard extends DashboardService {
  String? uid = 'navigator-a';
  final values = <String, DashboardSnapshot>{};
  final updates = <String, StreamController<DashboardSnapshot>>{};
  final activity = <bool>[];
  @override
  String? get currentUid => uid;
  @override
  Future<void> presence(bool active) async {
    activity.add(active);
  }

  @override
  Stream<DashboardSnapshot> watch(String uid) => Stream.multi((controller) {
    final sub =
        (updates[uid] ??= StreamController<DashboardSnapshot>.broadcast())
            .stream
            .listen(controller.add, onError: controller.addError);
    if (values[uid] != null) controller.add(values[uid]!);
    controller.onCancel = sub.cancel;
  });
  Future<void> close() async {
    for (final stream in updates.values) {
      await stream.close();
    }
  }
}

PairingConnection link(String suffix) => PairingConnection(
  id: suffix,
  navigatorUid: 'navigator-$suffix',
  caregiverUid: 'caregiver',
  navigatorName: 'Navigator $suffix',
  caregiverName: 'Caregiver',
  status: 'active',
);
DashboardSnapshot snapshot(String uid, {bool active = false}) =>
    DashboardSnapshot(
      uid: uid,
      name: uid,
      position: const LatLng(7.3, 125.68),
      locationTime: DateTime.now(),
      presence: 'active',
      presenceTime: DateTime.now(),
      target: const LatLng(7.31, 125.69),
      destination: 'Synthetic Park, Sample street',
      routeActive: active,
      routeStatus: active ? 'Active' : null,
      points: const [LatLng(7.299, 125.68), LatLng(7.3, 125.68)],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 22, 12);
  test(
    'null fields and invalid coordinates never become fake locations or blank cards',
    () {
      final data = DashboardSnapshot.fromJson({
        'navigator': {'uid': 'synthetic', 'name': ' '},
        'location': {'latitude': 91, 'longitude': true, 'heading': -1},
        'navigation': {'destination': ' '},
      });
      expect(data.position, isNull);
      expect(data.heading, isNull);
      expect(data.name, 'Navigator');
      expect(data.destinationName, 'No destination selected');
      expect(data.status(now), 'Unavailable');
      expect(data.headingLabel, 'No active route');
    },
  );
  test(
    'foreground activity, fresh GPS and route arrival are independent signals',
    () {
      final raw = {
        'navigator': {'uid': 'synthetic'},
        'location': {
          'latitude': 7.3,
          'longitude': 125.68,
          'time': now.millisecondsSinceEpoch,
          'heading': 45,
        },
        'presence': {'state': 'active', 'updatedAt': now.toIso8601String()},
        'navigation': {
          'active': true,
          'status': 'Active',
          'destination': 'Sample Park, Example street',
        },
      };
      final data = DashboardSnapshot.fromJson(raw);
      expect(data.status(now), 'Active');
      expect(data.headingLabel, 'North-east · 45°');
      expect(data.trackingLabel(now), contains('Live tracking active'));
      expect(data.status(now.add(const Duration(seconds: 46))), 'Offline');
      final background = DashboardSnapshot.fromJson({
        ...raw,
        'presence': {'state': 'inactive'},
      });
      expect(background.trackingLabel(now), contains('App inactive'));
      expect(
        background.trackingLabel(now),
        isNot(contains('Live tracking active')),
      );
      final arrived = DashboardSnapshot.fromJson({
        ...raw,
        'navigation': {'status': 'Completed', 'endedAt': now.toIso8601String()},
      });
      expect(arrived.status(now), 'Arrived');
    },
  );
  testWidgets(
    'metric cards, fallback states and map controls fit large text in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final theme in [GabayTheme.lightTheme, GabayTheme.darkTheme]) {
        final data = snapshot('synthetic', active: true);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: DashboardNavigationView(
                    data: data,
                    now: DateTime.now(),
                    eta: '8 min',
                    mapBuilder: (_, _, _) => const ColoredBox(
                      key: ValueKey('interactive-map'),
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final label in [
          'Navigation status',
          'Current heading',
          'Destination',
          'Estimated arrival',
          '8 min',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.byKey(const ValueKey('interactive-map')), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardNavigationView(
                data: const DashboardSnapshot(
                  uid: 'synthetic',
                  name: 'Navigator',
                ),
                now: now,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No GPS location yet'), findsOneWidget);
      expect(find.text('No destination selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'caregiver switches Navigators and removes locations after access is revoked',
    (tester) async {
      final service = FakeDashboard()
        ..values.addAll({
          'navigator-a': snapshot('navigator-a'),
          'navigator-b': snapshot('navigator-b'),
        });
      final pairing = FakePairing()..rows = [link('a'), link('b')];
      String? shown;
      int peers = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardLiveSection(
                caregiver: true,
                onViewMap: () {},
                service: service,
                pairing: pairing,
                mapBuilder: (data, others, _) {
                  shown = data.uid;
                  peers = others.length;
                  return const SizedBox(key: ValueKey('map'));
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(shown, 'navigator-a');
      expect(peers, 2);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Navigator b · Idle'));
      await tester.pumpAndSettle();
      expect(shown, 'navigator-b');
      pairing.updates.add([]);
      await tester.pumpAndSettle();
      expect(find.textContaining('No paired Navigators yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('map')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await service.close();
      await pairing.close();
    },
  );
  testWidgets(
    'late route estimates cannot overwrite the newly selected Navigator',
    (tester) async {
      final service = FakeDashboard()
        ..values.addAll({
          'navigator-a': snapshot('navigator-a', active: true),
          'navigator-b': snapshot('navigator-b', active: true),
        });
      final pairing = FakePairing()..rows = [link('a'), link('b')];
      final first = Completer<OsrmRouteGeometry?>(),
          second = Completer<OsrmRouteGeometry?>();
      int calls = 0;
      List<LatLng> shown = [];
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardLiveSection(
                caregiver: true,
                onViewMap: () {},
                service: service,
                pairing: pairing,
                routeLoader: (_, _) =>
                    ++calls == 1 ? first.future : second.future,
                mapBuilder: (_, _, route) {
                  shown = route;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Navigator b · Active'));
      await tester.pumpAndSettle();
      const newPoints = [LatLng(7.3, 125.68), LatLng(7.31, 125.69)];
      second.complete(
        const OsrmRouteGeometry(
          points: newPoints,
          distanceMeters: 1000,
          durationSeconds: 600,
        ),
      );
      await tester.pumpAndSettle();
      expect(shown, newPoints);
      first.complete(
        const OsrmRouteGeometry(
          points: [LatLng(1, 1), LatLng(2, 2)],
          distanceMeters: 500,
          durationSeconds: 60,
        ),
      );
      await tester.pumpAndSettle();
      expect(shown, newPoints);
      await tester.pumpWidget(const SizedBox());
      await service.close();
      await pairing.close();
    },
  );
  testWidgets(
    'activity heartbeat follows app foreground state without changing tracking',
    (tester) async {
      final service = FakeDashboard();
      final session = AppSessionService.instance;
      final logged = session.isLoggedIn, role = session.role;
      session.isLoggedIn = true;
      session.role = UserRole.navigator;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final reporter = DashboardPresenceReporter(service)..start();
      await tester.pump();
      expect(service.activity.last, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(service.activity.last, isFalse);
      reporter.dispose();
      await tester.pump();
      session.isLoggedIn = logged;
      session.role = role;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await service.close();
    },
  );
}
