import 'dart:async';
import 'package:app_mobile/models/pairing.dart';
import 'package:app_mobile/models/navigator_health_details.dart';
import 'package:app_mobile/models/patient_profile.dart';
import 'package:app_mobile/models/patient_health_status.dart';
import 'package:app_mobile/pages/caregiver/navigator_health_details_page.dart';
import 'package:app_mobile/services/pairing_service.dart';
import 'package:app_mobile/services/navigator_health_service.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Links extends PairingService {
  List<PairingConnection> rows = [
    for (final id in ['First', 'Second'])
      PairingConnection(
        id: id,
        navigatorUid: id,
        caregiverUid: 'caregiver',
        navigatorName: '$id Navigator',
        caregiverName: 'Caregiver',
        status: 'active',
        navigatorUserId: 'backend-$id',
      ),
    const PairingConnection(
      id: 'old',
      navigatorUid: 'old',
      caregiverUid: 'caregiver',
      navigatorName: 'Revoked Navigator',
      caregiverName: 'Caregiver',
      status: 'revoked',
    ),
  ];
  final updates = StreamController<List<PairingConnection>>.broadcast();
  @override
  Stream<List<PairingConnection>> watchConnections() =>
      Stream.multi((controller) {
        final sub = updates.stream.listen(controller.add);
        controller.add(rows);
        controller.onCancel = sub.cancel;
      });
  Future<void> close() => updates.close();
}

class _Health extends NavigatorHealthService {
  final requested = <String>[];
  final updates = <String, StreamController<NavigatorHealthDetails>>{};
  final values = <String, NavigatorHealthDetails>{};
  @override
  Stream<NavigatorHealthDetails> watch(String uid) {
    requested.add(uid);
    return Stream.multi((controller) {
      final sub =
          (updates[uid] ??=
                  StreamController<NavigatorHealthDetails>.broadcast())
              .stream
              .listen(controller.add, onError: controller.addError);
      controller.add(
        values[uid] ??
            NavigatorHealthDetails(
              uid: uid,
              profile: const PatientProfile(
                age: 30,
                gender: 'Synthetic gender',
                bloodType: 'Synthetic type',
              ),
              health: PatientHealthStatus(
                height: 170,
                weight: 60,
                medicalConditions: 'Synthetic condition $uid',
                allergies: 'Synthetic allergy $uid',
              ),
            ),
      );
      controller.onCancel = sub.cancel;
    });
  }

  Future<void> close() async {
    for (final stream in updates.values) {
      await stream.close();
    }
  }
}

void main() {
  testWidgets(
    'Health sections remain readable on a narrow dark phone with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final links = _Links(), health = _Health();
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: NavigatorHealthDetailsPage(
            service: links,
            healthService: health,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Address'));
      await tester.pumpAndSettle();
      expect(find.text('Personal Details'), findsOneWidget);
      expect(find.text('Synthetic condition First'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await links.close();
      await health.close();
    },
  );
  testWidgets(
    'Caregiver selects real linked identities without showing own health record',
    (tester) async {
      final links = _Links(), health = _Health();
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.darkTheme,
          home: NavigatorHealthDetailsPage(
            service: links,
            healthService: health,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('First Navigator'), findsOneWidget);
      expect(find.text('Health Overview'), findsOneWidget);
      expect(find.text('Synthetic condition First'), findsOneWidget);
      expect(find.text('170 cm'), findsOneWidget);
      expect(find.byTooltip('Edit health details'), findsNothing);
      await tester.tap(find.byTooltip('Select navigator'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Revoked Navigator'), findsNothing);
      await tester.tap(find.text('Second Navigator'));
      await tester.pumpAndSettle();
      expect(find.text('Second Navigator'), findsOneWidget);
      expect(find.text('First Navigator'), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(health.requested, ['First', 'Second']);
      expect(find.text('Synthetic condition Second'), findsOneWidget);
      health.updates['First']!.add(const NavigatorHealthDetails(uid: 'First'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Synthetic condition First'), findsNothing);
      expect(find.textContaining('Synthetic condition Second'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await links.close();
      await health.close();
    },
  );

  testWidgets(
    'explicit health clears remain unknown instead of showing old profile fields',
    (tester) async {
      final links = _Links(), health = _Health();
      health.values['First'] = const NavigatorHealthDetails(
        uid: 'First',
        profile: PatientProfile(
          medicalConditions: 'Old synthetic condition',
          allergies: 'Old synthetic allergy',
        ),
        health: PatientHealthStatus(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: NavigatorHealthDetailsPage(
            service: links,
            healthService: health,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Not provided'), findsWidgets);
      expect(find.textContaining('Old synthetic'), findsNothing);
      expect(find.byTooltip('Edit health details'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await links.close();
      await health.close();
    },
  );

  testWidgets(
    'fetch errors and revoked connections remove previously displayed health data',
    (tester) async {
      final links = _Links(), health = _Health();
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: NavigatorHealthDetailsPage(
            service: links,
            healthService: health,
          ),
        ),
      );
      await tester.pumpAndSettle();
      health.updates['First']!.addError(StateError('Synthetic denied access'));
      await tester.pumpAndSettle();
      expect(find.text('Health information not available'), findsOneWidget);
      expect(find.textContaining('Synthetic condition First'), findsNothing);
      links.updates.add([]);
      await tester.pumpAndSettle();
      expect(find.text('No connected navigators yet.'), findsOneWidget);
      expect(
        health.updates.values.every((stream) => !stream.hasListener),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      await links.close();
      await health.close();
    },
  );
}
