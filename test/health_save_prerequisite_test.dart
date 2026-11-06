import 'package:app_mobile/pages/caregiver/navigator_health_details_page.dart';
import 'package:app_mobile/models/patient_health_status.dart';
import 'package:app_mobile/models/patient_profile.dart';
import 'package:app_mobile/pages/caregiver/caregiver_profile.dart' as caregiver;
import 'package:app_mobile/pages/shared/information_health_status_page.dart';
import 'package:app_mobile/services/health_status_service.dart';
import 'package:app_mobile/services/profile_service.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/profile/profile_menu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store {
  bool profileReady = false;
  bool unavailable = false;
  int profileWrites = 0;
  PatientProfile? patient;
  PatientHealthStatus? health;
}

class _Profiles extends ProfileService {
  _Profiles(this.store, this.profile);
  final _Store store;
  final ProfileBundle profile;
  @override
  Future<ProfileBundle> saveProfile({
    required String name,
    required String phone,
    String? profilePicture,
    required PatientProfile patient,
  }) async {
    store.profileReady = true;
    store.profileWrites++;
    store.patient = patient;
    return ProfileBundle(
      userId: profile.userId,
      email: profile.email,
      role: profile.role,
      name: name,
      phone: phone,
      patientProfile: PatientProfile(
        profileId: 'synthetic-profile',
        userId: profile.userId,
        age: patient.age,
        gender: patient.gender,
        birthdate: patient.birthdate,
        medicalConditions: patient.medicalConditions,
        allergies: patient.allergies,
        bloodType: patient.bloodType,
        emergencyContact: patient.emergencyContact,
        address: patient.address,
      ),
    );
  }
}

class _Health extends HealthStatusService {
  _Health(this.store);
  final _Store store;
  @override
  Future<PatientHealthStatus?> fetch() async => store.health;
  @override
  Future<PatientHealthStatus> save(PatientHealthStatus status) async {
    if (!store.profileReady) {
      throw ProfileException(
        'Save your patient profile before adding health status.',
        statusCode: 409,
      );
    }
    if (store.unavailable) {
      throw ProfileException(
        'Health status service unavailable.',
        statusCode: 503,
      );
    }
    return store.health = status;
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    _Store store, {
    bool caregiver = false,
    bool existing = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final profile = ProfileBundle(
      userId: 'synthetic-owner',
      email: 'owner@example.test',
      role: caregiver ? 'caregiver' : 'visually_impaired',
      name: 'Test User',
      patientProfile: PatientProfile(
        profileId: existing ? 'existing-profile' : null,
        gender: 'Female',
        age: 25,
        bloodType: 'O+',
        emergencyContact: 'Test Contact',
        address: 'Test address',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: Scaffold(
          body: InformationHealthContent(
            profile: profile,
            healthService: _Health(store),
            profileService: _Profiles(store, profile),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit health details'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('height')));
    await tester.enterText(find.byKey(const ValueKey('height')), '165');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
  }

  for (final caregiver in [false, true]) {
    testWidgets(
      'Creates missing profile before saving ${caregiver ? "caregiver" : "navigator"} health with unchanged blood/contact',
      (tester) async {
        final store = _Store();
        await open(tester, store, caregiver: caregiver);
        expect(store.profileWrites, 1);
        expect(store.health?.height, 165);
        expect(store.patient?.bloodType, 'O+');
        expect(store.patient?.emergencyContact, 'Test Contact');
        expect(store.patient?.gender, 'Female');
        expect(store.patient?.age, 25);
        expect(store.patient?.address, 'Test address');
        expect(find.text('Health status saved.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Existing unchanged profile is not rewritten for measurement save',
    (tester) async {
      final store = _Store()..profileReady = true;
      await open(tester, store, existing: true);
      expect(store.profileWrites, 0);
      expect(store.health?.height, 165);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Server failure retains entered fields and reports the service problem',
    (tester) async {
      final store = _Store()..unavailable = true;
      await open(tester, store);
      expect(store.health, isNull);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('height')))
            .controller!
            .text,
        '165',
      );
      expect(
        find.text(
          'The health service is unavailable. Your entries are retained. Please retry later.',
        ),
        findsOneWidget,
      );
      expect(find.text('Health status saved.'), findsNothing);
      expect(tester.takeException(), isNull);
      store.unavailable = false;
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(store.health?.height, 165);
      expect(store.profileWrites, 1);
      expect(find.text('Health status saved.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Caregiver Others opens Navigator Health Details page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: const caregiver.ProfilePage(),
      ),
    );
    await tester.pumpAndSettle();
    final entry = find.text('Navigator Health Details');
    await tester.ensureVisible(entry);
    final section = tester.widget<ProfileSectionCard>(
      find.ancestor(of: entry, matching: find.byType(ProfileSectionCard)).first,
    );
    expect(section.title, 'Others');
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(NavigatorHealthDetailsPage), findsOneWidget);
    expect(find.byType(InformationHealthStatusPage), findsNothing);
    expect(find.text('Navigator Health Details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
