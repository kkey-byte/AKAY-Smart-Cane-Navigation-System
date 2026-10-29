import 'package:app_mobile/models/patient_health_status.dart';
import 'package:app_mobile/services/health_status_service.dart';
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
  @override
  Future<PatientHealthStatus?> fetch() async => record;
  @override
  Future<PatientHealthStatus> save(PatientHealthStatus status) async {
    if (failSave) throw StateError('Synthetic save failure');
    record = status;
    return status;
  }
}

void main() {
  late FakeHealthService service;
  setUp(() => service = FakeHealthService());
  Future<void> mount(WidgetTester tester, {bool large = false}) async {
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
      await tester.scrollUntilVisible(find.text('Phone Number'), 200);
      expect(find.text('Test Caregiver'), findsOneWidget);
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
    await tester.ensureVisible(find.text('Save health status'));
    await tester.tap(find.text('Save health status'));
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
    await tester.ensureVisible(find.text('Save health status'));
    await tester.tap(find.text('Save health status'));
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
    expect(find.text('Registered Caregiver'), findsOneWidget);
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
    await tester.ensureVisible(find.text('Save health status'));
    await tester.tap(find.text('Save health status'));
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
}
