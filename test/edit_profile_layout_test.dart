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

class _CaregiverProfileService extends _ProfileService {
  @override
  Future<ProfileBundle> fetchProfile() async => ProfileBundle(
    userId: 'synthetic-caregiver',
    email: 'caregiver@example.test',
    role: 'caregiver',
    name: 'Test Caregiver',
    phone: '09000000000',
    patientProfile: _ProfileService.bundle.patientProfile,
  );
}

Future<void> _settleAndEdit(WidgetTester tester) async {
  await tester.pumpAndSettle();
  if (find.byTooltip('Edit profile').evaluate().isNotEmpty) {
    expect(find.byTooltip('Save'), findsNothing);
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.text('Save Changes'), findsNothing);
    final form = find.byType(Form);
    final blocker = tester.widget<AbsorbPointer>(
      find.descendant(of: form, matching: find.byType(AbsorbPointer)).first,
    );
    expect(blocker.absorbing, isTrue);
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Save'), findsNothing);
    expect(find.byTooltip('Back'), findsNothing);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  }
}

void main() {
  for (final caregiver in [true, false]) {
    testWidgets(
      '${caregiver ? "Caregiver" : "Navigator"} preserves the existing address and saves the selected birthdate',
      (tester) async {
        final service = caregiver
            ? _CaregiverProfileService()
            : _ProfileService();
        await tester.pumpWidget(
          MaterialApp(
            theme: GabayTheme.lightTheme,
            home: EditProfilePage(profileService: service),
          ),
        );
        await _settleAndEdit(tester);
        expect(find.text('Test address'), findsOneWidget);
        expect(find.text('30 / 08 / 2000'), findsOneWidget);
        expect(find.byIcon(Icons.calendar_month_rounded), findsNothing);
        expect(find.text('Region, Province, City, Barangay'), findsOneWidget);
        await tester.ensureVisible(find.byIcon(Icons.edit_calendar_outlined));
        await tester.tap(find.byIcon(Icons.edit_calendar_outlined));
        await _settleAndEdit(tester);
        final pickerTheme = Theme.of(
          tester.element(find.byType(DatePickerDialog)),
        ).datePickerTheme;
        expect(pickerTheme.headerBackgroundColor, const Color(0xFF173B82));
        await tester.tap(find.text('29'));
        await tester.tap(find.text('Save date'));
        await _settleAndEdit(tester);
        expect(find.text('29 / 08 / 2000'), findsOneWidget);
        await tester.ensureVisible(find.text('Save Changes'));
        await tester.tap(find.text('Save Changes'));
        await _settleAndEdit(tester);
        expect(service.saved?.address, 'Test address');
        expect(service.saved?.birthdate, DateTime(2000, 8, 29));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Caregiver uses the reference layout and preserves hidden health data on save',
    (tester) async {
      final service = _CaregiverProfileService();
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: EditProfilePage(profileService: service),
        ),
      );
      await _settleAndEdit(tester);
      expect(find.text('Caregiver'), findsOneWidget);
      expect(find.text('Blood type'), findsNothing);
      expect(find.text('Medical conditions'), findsNothing);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Enter your full name'), findsOneWidget);
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await _settleAndEdit(tester);
      expect(service.saved?.bloodType, 'O+');
      expect(service.saved?.emergencyContact, 'Test Caregiver');
      expect(service.saved?.medicalConditions, isNull);
      expect(service.saved?.allergies, isNull);
      expect(service.saved?.address, 'Test address');
      expect(tester.takeException(), isNull);
    },
  );

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
      await _settleAndEdit(tester);
      expect(find.text('Emergency Contact'), findsNothing);
      expect(find.text('Blood type'), findsNothing);
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await _settleAndEdit(tester);
      expect(service.saved?.emergencyContact, 'Test Caregiver');
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
    await _settleAndEdit(tester);
    await tester.ensureVisible(find.text('Street Name, Building, House No.'));
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Save'), findsNothing);
    expect(find.byTooltip('Back'), findsNothing);
    expect(find.text('Save Changes'), findsOneWidget);
  });
}
