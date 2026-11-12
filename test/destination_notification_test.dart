import 'dart:convert';
import 'package:app_mobile/models/gabay_notification.dart';
import 'package:app_mobile/services/notification_service.dart';
import 'package:app_mobile/services/secure_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'destination outcomes appear in the existing feed and persist receipts',
    () async {
      final row = <String, dynamic>{
        'id': 'assigned-trip',
        'status': 'arrived',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };
      final api = SecureApi(
        idToken: () async => 'synthetic-token',
        bases: ['http://synthetic.invalid/api'],
        client: MockClient((request) async {
          if (request.method == 'POST') {
            final action = jsonDecode(request.body)['action'];
            if (action == 'read') row['isRead'] = true;
            if (action == 'dismiss') row['dismissed'] = true;
            return http.Response('{"accepted":true}', 200);
          }
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('/alerts')
                  ? {'alerts': []}
                  : {
                      'notifications': [row],
                    },
            ),
            200,
          );
        }),
      );
      final service = NotificationService.forTest(api);
      await service.refresh();
      expect(service.notifications.single.title, 'Navigator arrived');
      expect(
        service.notifications.single.destination,
        NotificationDestination.track,
      );
      service.markAsRead(service.notifications.single.id);
      await pumpEventQueue();
      expect(service.notifications.single.isRead, true);
      row['status'] = 'not_arrived';
      await service.refresh();
      expect(service.notifications.single.title, 'Navigator has not arrived');
      service.delete(service.notifications.single.id);
      await pumpEventQueue();
      expect(service.notifications, isEmpty);
      service.reset();
    },
  );
}
