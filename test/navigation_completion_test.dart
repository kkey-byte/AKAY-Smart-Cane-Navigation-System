import 'dart:async';
import 'dart:convert';
import 'package:app_mobile/services/live_location_service.dart';
import 'package:app_mobile/services/navigation_persistence_service.dart';
import 'package:app_mobile/services/navigation_arrival.dart';
import 'package:app_mobile/services/secure_api.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/track/eta_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'navigation_start_widget_test.dart' show resultFor, placeA;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'arrival requires a fresh accurate GPS fix inside the existing 35-metre radius',
    () {
      final now = DateTime(2026, 11, 16, 12);
      bool arrived({
        double accuracy = 8,
        int age = 0,
        LatLng point = const LatLng(7, 125),
      }) => hasArrivedAtDestination(
        location: point,
        destination: const LatLng(7, 125),
        accuracy: accuracy,
        sampledAt: now.subtract(Duration(seconds: age)),
        now: now,
      );
      expect(arrived(), isTrue);
      expect(arrived(accuracy: 36), isFalse);
      expect(arrived(accuracy: double.nan), isFalse);
      expect(arrived(age: 46), isFalse);
      expect(arrived(age: -31), isFalse);
      expect(arrived(point: const LatLng(7.001, 125)), isFalse);
    },
  );

  test(
    'arrival completion and rapid Finish taps share one Completed request',
    () async {
      final prior = LiveLocationService.instance.sharingEnabled;
      LiveLocationService.instance.sharingEnabled = true;
      addTearDown(() => LiveLocationService.instance.sharingEnabled = prior);
      final response = Completer<http.Response>();
      final bodies = <Map<String, dynamic>>[];
      final service = NavigationPersistenceService.forTest(
        activeSessionId: 'synthetic-session',
        api: SecureApi(
          idToken: () async => 'synthetic-token',
          bases: ['http://synthetic.invalid/api'],
          client: MockClient((request) async {
            bodies.add(jsonDecode(request.body));
            return response.future;
          }),
        ),
      );
      final arrival = service.endSession();
      final tap = service.endSession(cancelled: true);
      await Future<void>.delayed(Duration.zero);
      expect(bodies.length, 1);
      expect(bodies.single['status'], 'Completed');
      response.complete(http.Response('{}', 200));
      await Future.wait([arrival, tap]);
      expect(service.hasActiveSession, isFalse);
      expect(service.syncError, isNull);
    },
  );

  test(
    'failed completion retains session so Finish can retry as Completed',
    () async {
      final prior = LiveLocationService.instance.sharingEnabled;
      LiveLocationService.instance.sharingEnabled = true;
      addTearDown(() => LiveLocationService.instance.sharingEnabled = prior);
      var attempts = 0;
      final service = NavigationPersistenceService.forTest(
        activeSessionId: 'synthetic-session',
        api: SecureApi(
          idToken: () async => 'synthetic-token',
          bases: ['http://synthetic.invalid/api'],
          client: MockClient((request) async {
            expect(jsonDecode(request.body)['status'], 'Completed');
            return http.Response('{}', ++attempts == 1 ? 503 : 200);
          }),
        ),
      );
      await service.endSession();
      expect(service.hasActiveSession, isTrue);
      expect(service.syncError, isNotNull);
      await service.endSession();
      expect(service.hasActiveSession, isFalse);
      expect(attempts, 2);
    },
  );

  testWidgets(
    'existing destination action changes to Finish Navigation after arrival',
    (tester) async {
      for (final arrived in [false, true]) {
        var presses = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: GabayTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: EtaCard(
                  route: resultFor(placeA),
                  timelineEntries: const [],
                  currentLocationAddress: 'Synthetic origin',
                  onDragDismiss: () {},
                  onCancelDestination: () => presses++,
                  hasArrived: arrived,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final label = arrived ? 'Finish Navigation' : 'Cancel Destination';
        expect(find.text(label), findsOneWidget);
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        expect(presses, 1);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
