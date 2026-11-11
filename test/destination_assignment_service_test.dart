import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app_mobile/models/route_plan.dart';
import 'package:app_mobile/services/destination_assignment_service.dart';
import 'package:app_mobile/services/secure_api.dart';

void main() {
  test('dispatch names the selected navigator as recipient', () async {
    final api = SecureApi(
      bases: ['https://example.test'],
      idToken: () async => 'synthetic-token',
      revision: () => 1,
      client: MockClient((request) async {
        expect(request.url.path, '/v2/navigators/target-navigator/destination');
        final body = jsonDecode(request.body) as Map;
        expect(body['navigator_id'], 'target-navigator');
        expect(body.containsKey('caregiver_id'), false);
        expect((body['destination'] as Map)['latitude'], 10);
        return http.Response('{}', 200);
      }),
    );
    await DestinationAssignmentService(api: api).send(
      'target-navigator',
      const MapPlace(
        id: 'place',
        name: 'Destination',
        address: 'Test',
        latitude: 10,
        longitude: 20,
      ),
    );
  });
}
