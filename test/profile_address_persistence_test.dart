import 'dart:convert';

import 'package:app_mobile/models/patient_profile.dart';
import 'package:app_mobile/models/profile_address.dart';
import 'package:app_mobile/services/app_session_service.dart';
import 'package:app_mobile/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const address = ProfileAddress(
    region: 'Synthetic Region',
    province: 'Synthetic Province',
    city: 'Synthetic City',
    barangay: 'Synthetic Barangay',
    postalCode: '1234',
    street: 'Unit: 2\nSynthetic Street',
  );
  final session = AppSessionService.instance;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    session.isLoggedIn = true;
    session.userId = 'synthetic-owner';
    session.identityRevision++;
    session.displayName = 'Before save';
  });
  tearDown(() {
    session.isLoggedIn = false;
    session.userId = null;
    session.identityRevision++;
  });

  Map<String, dynamic> response(String? stored, String role) => {
    'user': {
      'user_id': 'synthetic-owner',
      'email': 'synthetic@example.test',
      'role': role,
      'name': 'Synthetic User',
      'phone': '09000000000',
    },
    'patientProfile': {'address': stored},
    'profileComplete': true,
  };

  for (final role in ['caregiver', 'visually_impaired']) {
    test(
      '$role saves and reloads every address section through the HTTP payload',
      () async {
        String? stored;
        final client = MockClient((request) async {
          expect(request.url.path, '/api/profile');
          expect(request.headers['Authorization'], 'Bearer synthetic-token');
          if (request.method == 'PUT') {
            final body = jsonDecode(request.body) as Map;
            expect(body['address'], address.serialize());
            expect(body['name'], 'Synthetic User');
            expect(body['phone'], '09000000000');
            stored = body['address'] as String;
          }
          return http.Response(jsonEncode(response(stored, role)), 200);
        });
        ProfileService service() => ProfileService(
          client: client,
          baseUrl: 'https://synthetic.test/api',
          firebaseUid: () => 'synthetic-uid',
          idToken: () async => 'synthetic-token',
        );
        await service().saveProfile(
          name: 'Synthetic User',
          phone: '09000000000',
          patient: PatientProfile(address: address.serialize()),
        );
        final reloaded = await service().fetchProfile();
        expect(reloaded.patientProfile.address, address.serialize());
        final parsed = ProfileAddress.tryParse(
          reloaded.patientProfile.address!,
        )!;
        expect(parsed.region, address.region);
        expect(parsed.province, address.province);
        expect(parsed.city, address.city);
        expect(parsed.barangay, address.barangay);
        expect(parsed.postalCode, address.postalCode);
        expect(parsed.street, address.street);
      },
    );
  }

  test(
    'missing or truncated server address cannot produce a successful save',
    () async {
      for (final incomplete in [null, 'Region: Synthetic Region']) {
        final service = ProfileService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode(response(incomplete, 'caregiver')),
              200,
            ),
          ),
          baseUrl: 'https://synthetic.test/api',
          firebaseUid: () => 'synthetic-uid',
          idToken: () async => 'synthetic-token',
        );
        await expectLater(
          service.saveProfile(
            name: 'Synthetic User',
            phone: '09000000000',
            patient: PatientProfile(address: address.serialize()),
          ),
          throwsA(
            isA<ProfileException>().having(
              (e) => e.message,
              'message',
              contains('complete address'),
            ),
          ),
        );
        expect(session.displayName, 'Before save');
      }
    },
  );

  test(
    'omitting an address preserves the server address without requiring an edit',
    () async {
      final service = ProfileService(
        client: MockClient((request) async {
          expect(
            (jsonDecode(request.body) as Map).containsKey('address'),
            isFalse,
          );
          return http.Response(
            jsonEncode(response(address.serialize(), 'caregiver')),
            200,
          );
        }),
        baseUrl: 'https://synthetic.test/api',
        firebaseUid: () => 'synthetic-uid',
        idToken: () async => 'synthetic-token',
      );
      final saved = await service.saveProfile(
        name: 'Synthetic User',
        phone: '09000000000',
        patient: const PatientProfile(),
      );
      expect(saved.patientProfile.address, address.serialize());
    },
  );
}
