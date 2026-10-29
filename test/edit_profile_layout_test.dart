import 'package:app_mobile/models/patient_profile.dart';
import 'package:app_mobile/pages/shared/edit_profile_page.dart';
import 'package:app_mobile/services/profile_service.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ProfileService extends ProfileService {
  PatientProfile? saved;

  static final bundle = ProfileBundle(
    userId: 'synthetic-user',
    email: 'navigator@example.test',
    role: 'visually_impaired',
    name: 'Test Navigator',
    phone: '09000000000',
    patientProfile: PatientProfile(
      gender: 'Female',
      birthdate: DateTime(2000, 8, 30),
      bloodType: 'O+',
      emergencyContact: 'Test Caregiver',
      address: 'Test address',
    ),
  );

  @override
  Future<ProfileBundle> fetchProfile() async => bundle;

  @override
  Future<ProfileBundle> saveProfile({
    required String name,
    required String phone,
    String? profilePicture,
    required PatientProfile patient,
  }) async {
    saved = patient;
    return bundle;
  }
}

void main() {
  testWidgets(
    'caregiver name loads and saves as the single emergency contact',
    (tester) async {
      final service = _ProfileService();
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: EditProfilePage(profileService: service),
        ),
      );
      await tester.pumpAndSettle();
      final emergency = find.widgetWithText(TextFormField, 'Test Caregiver');
      await tester.ensureVisible(emergency);
      expect(find.text('Emergency Contact'), findsOneWidget);
      expect(find.text('Relationship'), findsNothing);
      expect(find.text('Number'), findsNothing);
      await tester.enterText(emergency, 'Updated Caregiver');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(service.saved?.emergencyContact, 'Updated Caregiver');
      expect(service.saved?.address, 'Test address');
      expect(service.saved?.bloodType, 'O+');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile tolerates large text in dark mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.8)),
          child: child!,
        ),
        home: EditProfilePage(profileService: _ProfileService()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Emergency Contact'));
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Save'), findsOneWidget);
  });
}
