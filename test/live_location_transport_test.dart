import 'dart:async';
import 'dart:convert';
import 'package:app_mobile/models/user_role.dart';
import 'package:app_mobile/services/app_session_service.dart';
import 'package:app_mobile/services/live_location_service.dart';
import 'package:app_mobile/services/secure_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final session = AppSessionService.instance;
  late String uid, email;
  late List<http.Request> requests;
  late LiveLocationService service;
  Completer<void>? gate;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'navigator';
    email = 'navigator@example.test';
    requests = [];
    gate = null;
    session.isLoggedIn = true;
    session.role = UserRole.navigator;
    session.email = email;
    session.identityRevision++;
    final api = SecureApi(
      idToken: () async => 'synthetic-token',
      revision: () => session.identityRevision,
      bases: ['https://example.test'],
      client: MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) await gate?.future;
        return http.Response('{"accepted":true}', 200);
      }),
    );
    service = LiveLocationService.forTest(
      () => uid,
      () => email,
      null,
      api: api,
    )..sharingEnabled = true;
  });

  Future<void> send(DateTime sample, {double latitude = 10}) => service.publish(
    deviceId: 'phone_$uid',
    latitude: latitude,
    longitude: 20,
    accuracy: 5,
    sampledAt: sample,
  );

  test(
    'phone updates and stop use the authenticated owner endpoint with capture times',
    () async {
      final capture = DateTime.now().subtract(const Duration(seconds: 1));
      await send(capture);
      expect(
        requests.single.url.path,
        '/v2/navigators/navigator/phone-location',
      );
      expect(requests.single.method, 'PUT');
      expect(
        requests.single.headers['Authorization'],
        'Bearer synthetic-token',
      );
      final body = jsonDecode(requests.single.body);
      expect(body['timestamp'], capture.millisecondsSinceEpoch);
      expect(body['source'], 'phone_gps');
      expect(body.containsKey('deviceId'), isFalse);
      await service.clear(deviceId: 'phone_navigator');
      expect(requests.last.method, 'DELETE');
      expect(jsonDecode(requests.last.body).keys, ['stoppedAt']);
    },
  );

  test(
    'slow networking keeps only the newest queued sample instead of building a stale backlog',
    () async {
      gate = Completer<void>();
      final now = DateTime.now();
      final first = send(now.subtract(const Duration(seconds: 3)));
      await Future<void>.delayed(Duration.zero);
      final middle = send(
        now.subtract(const Duration(seconds: 2)),
        latitude: 11,
      );
      final newest = send(now, latitude: 12);
      final delayedOlder = send(
        now.subtract(const Duration(seconds: 1)),
        latitude: 13,
      );
      gate!.complete();
      await Future.wait([first, middle, newest, delayedOlder]);
      expect(requests, hasLength(2));
      expect(jsonDecode(requests.last.body)['latitude'], 12);
      expect(
        jsonDecode(requests.last.body)['timestamp'],
        now.millisecondsSinceEpoch,
      );
    },
  );

  test('an account change invalidates the old queued publication', () async {
    gate = Completer<void>();
    final now = DateTime.now();
    final first = send(now.subtract(const Duration(seconds: 1)));
    await Future<void>.delayed(Duration.zero);
    final pending = send(now, latitude: 11);
    uid = 'other-navigator';
    email = session.email = 'other@example.test';
    session.identityRevision++;
    gate!.complete();
    await Future.wait([first, pending]);
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/v2/navigators/navigator/phone-location');
  });

  test(
    'caregivers, stale fixes and mismatched phone identities never send a publication',
    () async {
      await send(DateTime.now().subtract(const Duration(minutes: 1)));
      await service.publish(
        deviceId: 'physical-cane',
        latitude: 10,
        longitude: 20,
      );
      session.role = UserRole.caregiver;
      await send(DateTime.now());
      expect(requests, isEmpty);
    },
  );
}
