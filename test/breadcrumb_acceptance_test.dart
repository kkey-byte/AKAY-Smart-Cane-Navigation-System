import 'dart:convert';
import 'package:app_mobile/models/breadcrumb_trip.dart';
import 'package:app_mobile/services/breadcrumb_recorder.dart';
import 'package:app_mobile/services/breadcrumb_repository.dart';
import 'package:app_mobile/services/continuous_breadcrumb_tracker.dart';
import 'package:app_mobile/services/secure_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'no destination: walk, disconnect, pause, restart, retry lost acknowledgement and read back',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      var now = DateTime(2026, 11, 1, 12);
      final originalCapture = now;
      var fix = BreadcrumbPoint(10, 20, now, 5);
      var offline = false, loseFinalAcknowledgement = true;
      final storedPoints = <int, Map<String, dynamic>>{};
      final summary = <String, dynamic>{};
      final api = SecureApi(
        idToken: () async => 'synthetic-test-token',
        revision: () => 1,
        bases: ['https://example.test'],
        client: MockClient((request) async {
          if (offline) {
            return http.Response('{"message":"Synthetic offline"}', 503);
          }
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'trip': {
                  ...summary,
                  'ownerId': 'navigator',
                  'points': {
                    for (final p in storedPoints.entries)
                      p.key.toString(): {
                        'latitude': p.value['latitude'],
                        'longitude': p.value['longitude'],
                        'accuracy': p.value['accuracyMeters'],
                        'time': p.value['sampledAt'],
                      },
                  },
                },
              }),
              200,
            );
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (request.url.path.endsWith('/points')) {
            summary.addAll({
              'name': body['name'],
              'startedAt': body['startedAt'],
            });
            for (final p in body['points'] as List) {
              storedPoints[p['sequence'] as int] = Map<String, dynamic>.from(
                p as Map,
              );
            }
          } else {
            summary.addAll(body);
            if (body['status'] == 'completed' && loseFinalAcknowledgement) {
              loseFinalAcknowledgement = false;
              return http.Response(
                '{"message":"Synthetic lost acknowledgement"}',
                503,
              );
            }
          }
          return http.Response('{"accepted":true}', 200);
        }),
      );
      FirebaseBreadcrumbRepository repository() =>
          FirebaseBreadcrumbRepository(api: api);
      ContinuousBreadcrumbTracker trackerFor(BreadcrumbRecorder recorder) =>
          ContinuousBreadcrumbTracker(
            recorder: recorder,
            eligibleOwner: () => 'navigator',
            clock: () => now,
            currentPoint: () => fix,
            startLocation: () async {},
            backgroundRecording: (_) async {},
          );
      final recorder = BreadcrumbRecorder(repository(), preferences);
      final tracker = trackerFor(recorder);
      await tracker.resume(); // No destination or navigation session exists.
      final tripId = recorder.activeId!;
      await recorder.sync();
      offline = true;
      now = now.add(const Duration(seconds: 5));
      fix = BreadcrumbPoint(10.0002, 20, now, 5);
      await tracker.onLocation();
      now = now.add(const Duration(seconds: 5));
      fix = BreadcrumbPoint(10.00025, 20, now, 5);
      await tracker.onLocation();
      now = now.add(const Duration(seconds: 30));
      fix = BreadcrumbPoint(10.00025, 20, now, 5);
      await tracker.onLocation();
      await tracker.pause();
      await recorder.sync();
      expect(recorder.hasPending, isTrue);
      expect(recorder.trips.single.points, hasLength(3));
      final restarted = BreadcrumbRecorder(repository(), preferences);
      final restartedTracker = trackerFor(restarted);
      await restartedTracker.reconcile();
      expect(restartedTracker.requested, isFalse);
      expect(restarted.trips.single.id, tripId);
      offline = false;
      await restarted.sync(); // Server saved it, but response was lost.
      expect(restarted.hasPending, isTrue);
      final recovered = BreadcrumbRecorder(repository(), preferences);
      await recovered.openAccount('navigator');
      await recovered.sync();
      expect(recovered.hasPending, isFalse);
      expect(storedPoints, hasLength(3));
      final readBack = await repository().watchTrip('navigator', tripId).first;
      expect(readBack!.status, 'completed');
      expect(readBack.endedAt, now);
      expect(readBack.lastSampledAt, now);
      expect(readBack.points.first.time, originalCapture);
      expect(readBack.distanceMeters, greaterThan(0));
      expect(readBack.isFresh(now), isFalse);
      expect(
        readBack.points.map((p) => p.toJson()),
        recovered.trips.single.points.map((p) => p.toJson()),
      );
    },
  );
}
