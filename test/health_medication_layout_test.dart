import 'package:app_mobile/models/patient_health_status.dart';
import 'package:app_mobile/services/health_status_service.dart';
import 'package:app_mobile/services/profile_service.dart';
import 'package:app_mobile/widgets/shared/gabay_card.dart';
import 'package:app_mobile/models/patient_profile.dart';
import 'package:app_mobile/pages/shared/information_health_status_page.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const profile = ProfileBundle(
  userId: 'synthetic-user',
  email: 'navigator@example.test',
  role: 'visually_impaired',
  name: 'Test Navigator',
  patientProfile: PatientProfile(
    age: 25,
    gender: 'Female',
    bloodType: 'O+',
    emergencyContact: 'Test Caregiver',
    medicalConditions: 'Test condition, Other condition',
    allergies: 'Test allergy',
  ),
);

class FakeHealthService extends HealthStatusService {
  PatientHealthStatus? record;
  bool failSave = false;
  bool failFetch = false;
  @override
  Future<PatientHealthStatus?> fetch() async {
    if (failFetch) throw StateError('Synthetic failure');
    return record;
  }

  @override
  Future<PatientHealthStatus> save(PatientHealthStatus status) async {
    if (failSave) throw StateError('Synthetic save failure');
    record = status;
    return status;
  }
}

class _ProfileWriter extends ProfileService {
  PatientProfile? saved;
  @override
  Future<ProfileBundle> fetchProfile() async => profile;
  @override
  Future<ProfileBundle> saveProfile({
    required String name,
    required String phone,
    String? profilePicture,
    required PatientProfile patient,
  }) async {
    saved = patient;
    return ProfileBundle(
      userId: profile.userId,
      email: profile.email,
      role: profile.role,
      name: name,
      phone: phone,
      profilePicture: profilePicture,
      patientProfile: patient,
    );
  }
}

void main() {
  late FakeHealthService service;
  late _ProfileWriter writer;
  setUp(() {
    service = FakeHealthService();
    writer = _ProfileWriter();
  });
  Future<void> mount(WidgetTester tester, {bool large = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.resetDevicePixelRatio());
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(
      MaterialApp(
        theme: large ? GabayTheme.darkTheme : GabayTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
          child: child!,
        ),
        home: Scaffold(
          body: InformationHealthContent(
            profile: profile,
            healthService: service,
            profileService: writer,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'health cards replace medication fields without fabricating measurements',
    (tester) async {
      await mount(tester);
      expect(find.text('Height'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('Test condition'), findsOneWidget);
      expect(find.text('Other condition'), findsOneWidget);
      expect(find.text('Test allergy'), findsOneWidget);
      expect(find.text('Medication Details'), findsNothing);
      expect(find.text('Address'), findsNothing);
      final cardHeights = ['Blood Type', 'Height', 'Weight']
          .map(
            (label) => tester
                .getSize(
                  find
                      .ancestor(
                        of: find.text(label),
                        matching: find.byType(GabayCard),
                      )
                      .first,
                )
                .height,
          )
          .toSet();
      expect(cardHeights.length, 1);
      await tester.scrollUntilVisible(find.text('Phone Number'), 200);
      expect(find.text('Test Caregiver'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Overview edits all supported fields using the existing profile and health saves',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byTooltip('Edit health details'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('blood_type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AB+').last);
      await tester.pumpAndSettle();
      for (final entry in {
        'height': '166',
        'weight': '61',
        'medical_conditions': 'Updated condition',
        'allergies': 'Updated allergy',
        'contact_name': 'Updated contact',
        'phone_number': '09000000001',
      }.entries) {
        final field = find.byKey(ValueKey(entry.key));
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(writer.saved?.bloodType, 'AB+');
      expect(writer.saved?.emergencyContact, 'Updated contact');
      expect(writer.saved?.gender, profile.patientProfile.gender);
      expect(writer.saved?.age, profile.patientProfile.age);
      expect(service.record?.height, 166);
      expect(service.record?.weight, 61);
      expect(service.record?.medicalConditions, 'Updated condition');
      expect(service.record?.allergies, 'Updated allergy');
      expect(service.record?.emergencyContactPhone, '09000000001');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('health editor validates, saves and reloads confirmed values', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byTooltip('Edit health details'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('height')), '-1');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a positive number'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('height')));
    await tester.enterText(find.byKey(const ValueKey('height')), '165');
    await tester.enterText(find.byKey(const ValueKey('weight')), '62');
    await tester.ensureVisible(find.byKey(const ValueKey('phone_number')));
    await tester.enterText(
      find.byKey(const ValueKey('phone_number')),
      '09000000000',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('09000000000'), 200);
    expect(service.record?.height, 165);
    expect(service.record?.emergencyContactPhone, '09000000000');
    await tester.pumpWidget(const SizedBox());
    await mount(tester);
    await tester.scrollUntilVisible(find.text('09000000000'), 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('health cards tolerate large text in dark mode', (tester) async {
    await mount(tester, large: true);
    await tester.scrollUntilVisible(find.text('Phone Number'), 200);
    expect(find.text('Emergency contact'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed health save retains the editor and entered values', (
    tester,
  ) async {
    service.failSave = true;
    await mount(tester);
    await tester.tap(find.byTooltip('Edit health details'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('medical_conditions')),
      'Retained condition',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to save health status. Your entries are retained.'),
      findsOneWidget,
    );
    expect(find.text('Retained condition'), findsOneWidget);
    expect(service.record, isNull);
    expect(find.text('Health status saved.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('health-load warning disappears automatically', (tester) async {
    service.failFetch = true;
    await mount(tester);
    expect(find.text('Unable to load health information.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load health information.'), findsNothing);
    expect(find.byTooltip('Edit health details'), findsOneWidget);
  });

  testWidgets('load error retries cleanly without a permanent warning', (
    tester,
  ) async {
    service.failFetch = true;
    await mount(tester);
    expect(find.text('Unable to load health information.'), findsOneWidget);
    service.failFetch = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load health information.'), findsNothing);
  });

  testWidgets(
    'section edit opens relevant fields first and cancel preserves data',
    (tester) async {
      await mount(tester);
      await tester.ensureVisible(find.byTooltip('Edit health details'));
      await tester.tap(find.byTooltip('Edit health details'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('medical_conditions'));
      await tester.enterText(field, 'Unsaved entry');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.record, isNull);
      expect(writer.saved, isNull);
      expect(find.text('Unsaved entry'), findsNothing);
    },
  );
  testWidgets(
    'one overview edit action includes emergency contact after a load failure',
    (tester) async {
      service.failFetch = true;
      await mount(tester);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byTooltip('Edit emergency contact'), findsNothing);
      await tester.tap(find.byTooltip('Edit health details'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('height')), '170');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Edit health details'));
      await tester.tap(find.byTooltip('Edit health details'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('contact_name')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('contact_name')),
        'Editable contact',
      );
      expect(find.text('Editable contact'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'health refresh reloads supported fields and preserves values on failure',
    (tester) async {
      service.record = const PatientHealthStatus(height: 160);
      await mount(tester);
      service.record = const PatientHealthStatus(height: 175);
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refresh.onRefresh();
      await tester.pumpAndSettle();
      expect(find.textContaining('175', findRichText: true), findsOneWidget);
      service.failFetch = true;
      await refresh.onRefresh();
      await tester.pumpAndSettle();
      expect(find.textContaining('175', findRichText: true), findsOneWidget);
      expect(find.text('Unable to load health information.'), findsOneWidget);
    },
  );
}
