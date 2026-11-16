import 'package:app_mobile/models/pairing.dart';
import 'package:app_mobile/models/cane_registration_challenge.dart';
import 'package:app_mobile/pages/visually_impaired/vi_caregivers_page.dart';
import 'package:app_mobile/pages/shared/pairing_management_page.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/shared/dashboard_pairing_card.dart';
import 'package:app_mobile/widgets/profile/navigator_smart_cane_section.dart';
import 'package:app_mobile/widgets/shared/gabay_action_card_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dashboard_pairing_test.dart' show DashboardFake;

class _Devices extends DashboardFake {
  List<RegisteredCane> canes = [];
  bool failDevices = false;
  bool failRegistration = false;
  String? registrationError;
  String? acceptedTransfer;
  @override
  Future<void> acceptTransfer(String code) async {
    acceptedTransfer = code;
  }

  List<String>? claimed;
  List<String>? requested;
  @override
  Future<CaneRegistrationChallenge> requestCaneRegistration([
    String? id,
    String? code,
  ]) async {
    requested = [];
    if (registrationError != null) throw StateError(registrationError!);
    if (failRegistration) {
      throw StateError('No cane is authorized for your account.');
    }
    return CaneRegistrationChallenge(
      id: 'registration-id',
      code: 'ABCD23',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  @override
  Future<void> confirmCaneRegistration(String id, String code) async {
    if (id != 'registration-id' || code != 'ABCD23') {
      throw StateError('Registration code does not match.');
    }
    await claim('synthetic-device', 'server-authorized');
  }

  @override
  Future<List<RegisteredCane>> devices() async {
    if (failDevices) throw StateError('Synthetic device error');
    return canes;
  }

  @override
  Future<void> claim(String id, String code) async {
    claimed = [id, code];
    canes = [
      RegisteredCane(id: id, serial: 'Test Cane', assignmentId: 'assignment'),
    ];
  }
}

void main() {
  testWidgets('Smart Cane transfer uses the original acceptance service', (
    tester,
  ) async {
    final service = _Devices();
    await tester.pumpWidget(
      MaterialApp(
        theme: GabayTheme.lightTheme,
        home: PairingManagementPage(
          caregiver: false,
          devicesOnly: true,
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Accept Transfer'));
    await tester.tap(find.text('Accept Transfer'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Private transfer code'),
      'synthetic-transfer',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(service.acceptedTransfer, 'synthetic-transfer');
    await tester.pumpWidget(const SizedBox());
    await service.close();
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    testWidgets(
      'registration rate limit stays distinct from missing authorization dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = _Devices()
          ..registrationError = 'Too many attempts. Wait before trying again.';
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? GabayTheme.darkTheme : GabayTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: PairingManagementPage(
              caregiver: false,
              devicesOnly: true,
              registerOnOpen: true,
              service: service,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Too many attempts'), findsOneWidget);
        expect(find.textContaining('Ask the cane provider'), findsNothing);
        expect(find.text('Register'), findsNothing);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await service.close();
      },
    );
  }
  testWidgets(
    'unknown device loading state renders without a bool cast error',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: Scaffold(
            body: NavigatorSmartCaneSection(
              devices: null,
              loading: null,
              onManage: () {},
              onRetry: () {},
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final config in [
    (320.0, 1.0, false),
    (390.0, 1.0, false),
    (760.0, 1.0, false),
    (320.0, 2.0, true),
  ]) {
    testWidgets(
      'connections actions fit width=${config.$1} scale=${config.$2}',
      (tester) async {
        tester.view.physicalSize = Size(config.$1, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = _Devices();
        await tester.pumpWidget(
          MaterialApp(
            theme: config.$3 ? GabayTheme.darkTheme : GabayTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(config.$2)),
              child: child!,
            ),
            home: ViCaregiversPage(service: service),
          ),
        );
        await tester.pumpAndSettle();
        final invite = tester.getTopLeft(find.text('Invite a Caregiver'));
        final cane = tester.getTopLeft(find.text('Register Smart Cane'));
        expect(cane.dy, greaterThan(invite.dy));
        expect(cane.dx, invite.dx);
        for (final header in find.byType(GabayActionCardHeader).evaluate()) {
          final parent = find.byWidget(header.widget);
          final icon = find
              .descendant(of: parent, matching: find.byType(Icon))
              .first;
          final texts = find.descendant(
            of: parent,
            matching: find.byType(Text),
          );
          expect(
            tester.getTopLeft(texts.first).dx,
            greaterThan(tester.getTopLeft(icon).dx),
          );
          expect(
            tester.getTopLeft(texts.first).dx,
            tester.getTopLeft(texts.last).dx,
          );
        }
        final codeButton = find.widgetWithText(FilledButton, 'Code');
        final qrButton = find.widgetWithText(FilledButton, 'QR');
        final registerButton = find.descendant(
          of: find.byType(SmartCaneActionCard),
          matching: find.byType(FilledButton),
        );
        expect(
          tester.getSize(codeButton).width,
          tester.getSize(qrButton).width,
        );
        expect(
          tester.getTopLeft(codeButton).dx,
          tester.getTopLeft(registerButton).dx,
        );
        expect(
          tester.getBottomRight(qrButton).dx,
          tester.getBottomRight(registerButton).dx,
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('caregiver-invitation-card')))
              .width,
          tester.getSize(find.byType(SmartCaneActionCard)).width,
        );
        expect(find.text('My Caregivers'), findsOneWidget);
        expect(find.text('Why add caregivers?'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('My Smart Cane'),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('No Smart Cane Registered'), findsOneWidget);
        expect(find.text('Register Cane'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(NavigatorSmartCaneSection),
            matching: find.byType(OutlinedButton),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await service.close();
      },
    );
  }

  testWidgets(
    'registration requests a server code and only registers after manual confirmation',
    (tester) async {
      final service = _Devices();
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: ViCaregiversPage(service: service),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.descendant(
        of: find.byType(SmartCaneActionCard),
        matching: find.text('Register Cane'),
      );
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Register a Cane'), findsOneWidget);
      expect(find.text('Create invitation'), findsNothing);
      expect(find.text('Permanent Device ID'), findsNothing);
      expect(find.text('Private claim code'), findsNothing);
      expect(service.requested, isEmpty);
      expect(service.claimed, isNull);
      expect(find.text('ABCD23'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Registration code'),
        'ABCD23',
      );
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(service.claimed, ['synthetic-device', 'server-authorized']);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('My Smart Cane'));
      expect(find.text('Test Cane'), findsOneWidget);
      expect(find.text('Registered'), findsOneWidget);
      expect(find.text('Assigned to you'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await service.close();
    },
  );

  for (final cancel in [false, true]) {
    testWidgets(
      'cane registration ${cancel ? 'cancellation never claims the cane' : 'wrong code can be corrected in the same modal'}',
      (tester) async {
        final service = _Devices();
        await tester.pumpWidget(
          MaterialApp(
            theme: GabayTheme.lightTheme,
            home: ViCaregiversPage(service: service),
          ),
        );
        await tester.pumpAndSettle();
        final action = find.descendant(
          of: find.byType(SmartCaneActionCard),
          matching: find.text('Register Cane'),
        );
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        if (cancel) {
          await tester.tap(find.text('Cancel'));
        } else {
          await tester.enterText(
            find.widgetWithText(TextField, 'Registration code'),
            'WRONG2',
          );
          await tester.tap(find.text('Register'));
        }
        await tester.pumpAndSettle();
        expect(service.claimed, isNull);
        expect(service.canes, isEmpty);
        expect(tester.takeException(), isNull);
        if (!cancel) {
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.enterText(
            find.widgetWithText(TextField, 'Registration code'),
            'ABCD23',
          );
          await tester.tap(find.text('Register'));
          await tester.pumpAndSettle();
          expect(service.claimed, ['synthetic-device', 'server-authorized']);
          expect(find.byType(AlertDialog), findsNothing);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        await service.close();
      },
    );
  }

  testWidgets(
    'Smart Cane register button opens the same single-modal flow at large text',
    (tester) async {
      final service = _Devices();
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: PairingManagementPage(
            caregiver: false,
            devicesOnly: true,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Register Cane'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Register Cane'));
      await tester.pumpAndSettle();
      expect(service.requested, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('ABCD23')).dy,
        lessThan(tester.getTopLeft(find.byType(TextField)).dy),
      );
      expect(
        tester.getTopLeft(find.byType(TextField)).dy,
        lessThan(
          tester.getTopLeft(find.widgetWithText(FilledButton, 'Register')).dy,
        ),
      );
      expect(find.text('Accept Transfer'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await service.close();
    },
  );

  testWidgets(
    'server code request failure stays in the registration modal without registering',
    (tester) async {
      final service = _Devices()..failRegistration = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: PairingManagementPage(
            caregiver: false,
            service: service,
            devicesOnly: true,
            registerOnOpen: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('No cane is authorized'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Register'), findsNothing);
      expect(service.claimed, isNull);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await service.close();
    },
  );

  testWidgets(
    'device errors keep pairing visible and retry reads the same service',
    (tester) async {
      final service = _Devices()..failDevices = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: ViCaregiversPage(service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DashboardPairingCard), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Retry device list'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      service.failDevices = false;
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry device list'));
      await tester.pumpAndSettle();
      expect(find.text('No Smart Cane Registered'), findsOneWidget);
      expect(find.text('Unable to load registered canes.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await service.close();
    },
  );
}
