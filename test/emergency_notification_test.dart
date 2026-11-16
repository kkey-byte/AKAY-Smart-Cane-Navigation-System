import 'dart:async';
import 'dart:convert';
import 'package:app_mobile/services/notification_service.dart';
import 'package:app_mobile/services/secure_api.dart';
import 'package:app_mobile/pages/caregiver/notifications_page.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> incident(String id, String uid, String kind) => {
  'id': id,
  'navigator_uid': uid,
  'navigator_name': 'Synthetic $uid',
  'device_id': 'synthetic-cane-$uid',
  'kind': kind,
  'created_at': DateTime.now().toUtc().toIso8601String(),
  'sampled_at': DateTime.now().toUtc().toIso8601String(),
  'latitude': null,
  'longitude': null,
  'acknowledged_at': null,
  'resolved_at': null,
  'read_at': null,
};
void main() {
  test(
    'temporary outage retains saved incidents but access denial clears them',
    () async {
      var status = 200;
      final service = NotificationService.forTest(
        SecureApi(
          client: MockClient(
            (request) async => http.Response(
              jsonEncode(
                request.url.path.endsWith('/alerts')
                    ? {
                        'alerts': [incident('a', 'user-one', 'sos')],
                      }
                    : {'notifications': []},
              ),
              status,
            ),
          ),
          idToken: () async => 'synthetic',
          bases: ['http://synthetic.invalid/api'],
        ),
      );
      await service.refresh();
      status = 503;
      await expectLater(service.refresh(), throwsA(isA<SecureApiException>()));
      expect(service.notifications.length, 1);
      status = 403;
      await expectLater(service.refresh(), throwsA(isA<SecureApiException>()));
      expect(service.notifications, isEmpty);
    },
  );
  test(
    'multi-navigator incidents keep identity and caregiver deletion is personal',
    () async {
      final rows = [
        incident('incident-a', 'user-one', 'sos'),
        incident('incident-b', 'user-two', 'motion'),
      ];
      final actions = <String>[];
      final api = SecureApi(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            final action = jsonDecode(request.body)['action'] as String;
            actions.add(action);
            if (action == 'dismiss') {
              final id = request.url.pathSegments.reversed.skip(1).first;
              rows.removeWhere((row) => row['id'] == id);
            }
            if (action == 'acknowledge') {
              rows.first['acknowledged_at'] = DateTime.now()
                  .toUtc()
                  .toIso8601String();
            }
            if (action == 'resolve') {
              rows.first['resolved_at'] = DateTime.now()
                  .toUtc()
                  .toIso8601String();
              rows.first['resolution'] = 'resolved';
            }
            return http.Response('{"accepted":true}', 200);
          }
          return http.Response(jsonEncode({'alerts': rows}), 200);
        }),
        idToken: () async => 'synthetic-token',
        bases: ['http://synthetic.invalid/api'],
      );
      final service = NotificationService.forTest(api);
      await service.refresh();
      expect(service.notifications.first.title, 'SOS — Synthetic user-one');
      expect(
        service.notifications.last.title,
        'Possible fall or impact — Synthetic user-two',
      );
      await service.respond('incident-a', 'acknowledge');
      expect(service.notifications.first.incident!.status, 'Acknowledged');
      expect(service.notifications.first.incident!.unresolved, isTrue);
      await service.respond('incident-a', 'resolve');
      expect(service.notifications.first.incident!.status, 'Resolved');
      expect(service.notifications.last.incident!.status, 'Needs response');
      service.delete('incident-b');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(service.notifications.length, 1);
      expect(actions.last, 'dismiss');
      service.clearAll();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(service.notifications, isEmpty);
    },
  );
  test(
    'identity reset drops in-flight feed and unconfirmed mutation never claims resolution',
    () async {
      final delayed = Completer<http.Response>();
      final service = NotificationService.forTest(
        SecureApi(
          client: MockClient((request) async {
            if (request.method == 'POST') {
              return http.Response('{"accepted":false}', 200);
            }
            return delayed.future;
          }),
          idToken: () async => 'synthetic',
          bases: ['http://synthetic.invalid/api'],
        ),
      );
      final request = service.refresh();
      await Future<void>.delayed(Duration.zero);
      service.reset();
      delayed.complete(
        http.Response(
          jsonEncode({
            'alerts': [incident('a', 'user-one', 'sos')],
          }),
          200,
        ),
      );
      await request;
      expect(service.notifications, isEmpty);
      await expectLater(
        service.respond('a', 'resolve'),
        throwsA(isA<SecureApiException>()),
      );
    },
  );
  testWidgets(
    'existing notification card opens accessible response dialog; opening does not resolve',
    (tester) async {
      final row = incident('a', 'user-one', 'motion');
      final actions = <String>[];
      final service = NotificationService.forTest(
        SecureApi(
          client: MockClient((request) async {
            if (request.method == 'POST') {
              final action = jsonDecode(request.body)['action'] as String;
              actions.add(action);
              row['read_at'] = DateTime.now().toIso8601String();
              if (action == 'acknowledge') {
                row['acknowledged_at'] = DateTime.now().toIso8601String();
              }
              if (action == 'dismiss') row['dismissed'] = true;
              return http.Response('{"accepted":true}', 200);
            }
            return http.Response(
              jsonEncode({
                'alerts': [if (row['dismissed'] != true) row],
              }),
              200,
            );
          }),
          idToken: () async => 'synthetic',
          bases: ['http://synthetic.invalid/api'],
        ),
      );
      await service.refresh();
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
            child: NotificationsPage(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Possible fall or impact — Synthetic user-one'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Status: Needs response'), findsOneWidget);
      expect(actions, ['read']);
      expect(
        find.text('No location was attached to this event.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Acknowledge'));
      await tester.pumpAndSettle();
      expect(find.text('Status: Acknowledged'), findsOneWidget);
      expect(actions, ['read', 'acknowledge']);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Delete notification'));
      await tester.pumpAndSettle();
      expect(service.notifications, isEmpty);
      expect(actions.last, 'dismiss');
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
