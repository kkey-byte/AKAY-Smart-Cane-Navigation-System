import 'dart:async';
import 'dart:convert';
import 'package:app_mobile/services/destination_assignment_service.dart';
import 'package:app_mobile/services/secure_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ReadOnlyPreferences extends Fake implements SharedPreferences {
  @override
  String? getString(String key) => null;
  @override
  Future<bool> setString(String key, String value) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? uid;
  late int revision;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'synthetic-nav';
    revision = 0;
  });
  DestinationAssignmentService create(
    Future<http.Response> Function(http.Request) handler, {
    Future<SharedPreferences> Function()? preferences,
  }) => DestinationAssignmentService(
    currentUid: () => uid,
    revision: () => revision,
    preferences: preferences,
    api: SecureApi(
      idToken: () async => 'synthetic-token',
      revision: () => revision,
      bases: ['http://synthetic.invalid/api'],
      client: MockClient(handler),
    ),
  );

  test(
    'offline cancel is saved before remote work and remains blocked after reopening',
    () async {
      final requests = <http.Request>[];
      Future<http.Response> offline(http.Request request) async {
        requests.add(request);
        if (request.method == 'POST') return http.Response('{}', 503);
        return http.Response('{"assignment":{"id":"old-assignment"}}', 200);
      }

      final service = create(offline);
      await service.cancel('old-assignment', sessionId: 'old-session');
      expect(await service.isCancelled('old-assignment'), isTrue);
      await service.flushCancellations();
      final reopened = create(offline);
      expect((await reopened.watch().first)['assignment'], isNull);
      await reopened.flushCancellations();
      expect(await reopened.isCancelled('old-assignment'), isTrue);
      final completed = create(
        (request) async => http.Response(
          request.url.path.endsWith('/cancel') ? '{"accepted":true}' : '{}',
          200,
        ),
      );
      await completed.flushCancellations();
      expect(await completed.isCancelled('old-assignment'), isTrue);
      requests.clear();
      await service.flushCancellations();
      expect(requests, isEmpty);
    },
  );
  test(
    'a destination response already in flight cannot restart the cancelled route',
    () async {
      final fetched = Completer<void>(), response = Completer<http.Response>();
      final service = create((request) async {
        if (request.method == 'GET') {
          fetched.complete();
          return response.future;
        }
        return http.Response('{"accepted":true}', 200);
      });
      final pending = service.watch().first;
      await fetched.future;
      await service.cancel('old-assignment');
      response.complete(
        http.Response('{"assignment":{"id":"old-assignment"}}', 200),
      );
      expect((await pending)['assignment'], isNull);
      await service.flushCancellations();
    },
  );
  test(
    'manual route cancellation ends only its captured session and does not call assignment cancellation',
    () async {
      final paths = <String>[];
      final service = create((request) async {
        paths.add(request.url.path);
        expect(jsonDecode(request.body), {
          'sessionId': 'captured-session',
          'status': 'Cancelled',
        });
        return http.Response('{}', 200);
      });
      await service.cancel(
        'place:123',
        assigned: false,
        sessionId: 'captured-session',
      );
      await service.flushCancellations();
      expect(paths, ['/api/navigation/end']);
    },
  );
  test(
    'unconfirmed cancellation retries and a genuinely new assignment still arrives',
    () async {
      var accepted = false, posts = 0;
      final service = create((request) async {
        if (request.method == 'POST') {
          posts++;
          return http.Response(jsonEncode({'accepted': accepted}), 200);
        }
        return http.Response('{"assignment":{"id":"new-assignment"}}', 200);
      });
      await service.cancel('old-assignment');
      await service.flushCancellations();
      final before = posts;
      accepted = true;
      await service.flushCancellations();
      expect(posts, greaterThan(before));
      expect(
        (await service.watch().first)['assignment']['id'],
        'new-assignment',
      );
      await service.flushCancellations();
    },
  );
  test('cancellations are scoped to the navigator account', () async {
    final service = create((_) async => http.Response('{}', 503));
    await service.cancel('old-assignment');
    await service.flushCancellations();
    uid = 'another-navigator';
    revision++;
    expect(await service.isCancelled('old-assignment'), isFalse);
    uid = 'synthetic-nav';
    revision++;
    expect(await service.isCancelled('old-assignment'), isTrue);
  });
  test(
    'failed local persistence cannot claim cancellation was saved',
    () async {
      var posts = 0;
      final service = create((_) async {
        posts++;
        return http.Response('{}', 200);
      }, preferences: () async => _ReadOnlyPreferences());
      await expectLater(service.cancel('old-assignment'), throwsStateError);
      expect(posts, 0);
    },
  );
}
