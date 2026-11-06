import 'package:app_mobile/models/profile_address.dart';
import 'package:app_mobile/services/philippine_address_service.dart';
import 'package:app_mobile/widgets/profile/address_editor_sheet.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Places extends PhilippineAddressService {
  @override
  Future<List<AddressPlace>> regions() async => [
    const AddressPlace('r', 'Test Region'),
    const AddressPlace('r2', 'Other Region'),
  ];
  @override
  Future<List<AddressPlace>> provinces(String region) async => [
    const AddressPlace('p', 'Test Province'),
  ];
  @override
  Future<List<AddressPlace>> cities(String region, String? province) async => [
    const AddressPlace('c', 'Test City'),
  ];
  @override
  Future<List<AddressPlace>> barangays(String city) async => [
    const AddressPlace('b', 'Test Barangay'),
  ];
}

void main() {
  test(
    'Address round-trip preserves typed multiline street and leaves legacy values unparsed',
    () {
      const address = ProfileAddress(
        region: 'Region',
        province: 'Province',
        city: 'City',
        barangay: 'Barangay',
        postalCode: '8105',
        street: 'Unit: 2\nSynthetic Street',
      );
      final restored = ProfileAddress.tryParse(address.serialize())!;
      expect(restored.street, address.street);
      expect(restored.postalCode, address.postalCode);
      expect(ProfileAddress.tryParse('A legacy free-form address'), isNull);
    },
  );
  test(
    'Directory only requests public geographic codes and parses resource envelopes',
    () async {
      final service = PhilippineAddressService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v2/regions');
          expect(request.headers.containsKey('authorization'), isFalse);
          return http.Response(
            '{"data":[{"code":"r","name":"Test Region"}]}',
            200,
          );
        }),
      );
      expect((await service.regions()).single.name, 'Test Region');
      service.dispose();
    },
  );
  testWidgets(
    'Cascading address selection returns one compatible address value',
    (tester) async {
      ProfileAddress? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<ProfileAddress>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => AddressEditorSheet(
                      initialAddress: 'Legacy address',
                      service: _Places(),
                    ),
                  );
                },
                child: const Text('Edit address'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit address'));
      await tester.pumpAndSettle();
      expect(find.text('Existing address: Legacy address'), findsOneWidget);
      Future<void> pick(String label, String name) async {
        final field = find
            .ancestor(
              of: find.text(label).last,
              matching: find.byType(InputDecorator),
            )
            .first;
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.tap(find.text(name).last);
        await tester.pumpAndSettle();
      }

      await pick('Region', 'Test Region');
      await pick('Province', 'Test Province');
      await pick('City / Municipality', 'Test City');
      await pick('Barangay', 'Test Barangay');
      await pick('Region', 'Other Region');
      expect(find.text('Select Province'), findsOneWidget);
      expect(find.text('Select City / Municipality'), findsOneWidget);
      expect(find.text('Select Barangay'), findsOneWidget);
      await pick('Province', 'Test Province');
      await pick('City / Municipality', 'Test City');
      await pick('Barangay', 'Test Barangay');
      final postal = find.widgetWithText(TextFormField, 'Postal Code');
      await tester.ensureVisible(postal);
      await tester.enterText(postal, '8105');
      final street = find.widgetWithText(
        TextFormField,
        'Street Name, Building, House No.',
      );
      await tester.ensureVisible(street);
      await tester.enterText(street, 'Synthetic Street, House 2');
      await tester.ensureVisible(find.text('Use this address'));
      await tester.tap(find.text('Use this address'));
      await tester.pumpAndSettle();
      expect(result?.region, 'Other Region');
      expect(result?.barangay, 'Test Barangay');
      expect(result?.street, 'Synthetic Street, House 2');
      expect(ProfileAddress.tryParse(result!.serialize())?.postalCode, '8105');
      final saved = result!;
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: Scaffold(
            body: AddressEditorSheet(
              initialAddress: saved.serialize(),
              service: _Places(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(saved.region), findsOneWidget);
      expect(find.text(saved.province), findsOneWidget);
      expect(find.text(saved.city), findsOneWidget);
      expect(find.text(saved.barangay), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Postal Code'),
            )
            .controller!
            .text,
        saved.postalCode,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(
                TextFormField,
                'Street Name, Building, House No.',
              ),
            )
            .controller!
            .text,
        saved.street,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
