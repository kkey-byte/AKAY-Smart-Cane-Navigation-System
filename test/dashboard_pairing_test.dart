import 'package:app_mobile/models/pairing.dart';
import 'package:app_mobile/models/pairing_code.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/shared/dashboard_pairing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'pairing_security_test.dart' show FakePairing;

PairingConnection connection(String id, {String status = 'pending'}) =>
    PairingConnection(
      id: id,
      navigatorUid: 'nav-$id',
      caregiverUid: 'caregiver',
      navigatorName: 'Navigator $id',
      caregiverName: 'Caregiver $id',
      status: status,
    );

class DashboardFake extends FakePairing {
  String? redeemed;
  String? method;
  @override
  Future<Map<String, dynamic>> generatePairing(String method) async => {
    'code': 'ABC234',
    'expires_at': DateTime.now()
        .add(const Duration(minutes: 10))
        .toIso8601String(),
  };
  @override
  Future<List<PairingConnection>> connections() async => rows;
  @override
  Future<void> redeemPairing(String code, String selectedMethod) async {
    redeemed = code;
    method = selectedMethod;
    rows = [connection('one', status: 'active')];
  }

  @override
  Future<void> decide(String id, bool accept) async {
    decided = accept ? 'accepted' : 'rejected';
    rows = [connection(id, status: accept ? 'active' : 'rejected')];
  }
}

void main() {
  test(
    'manual and QR codes normalize safely and reject unrelated payloads',
    () {
      expect(parsePairingCode(' abc234 '), 'ABC234');
      expect(parsePairingCode('akay://pair?code=abc234'), 'ABC234');
      for (final input in [
        'ABO234',
        'ABC230',
        'ABC231',
        'ABCI23',
        'https://example.test/?code=ABC234',
        'akay://other?code=ABC234',
        'akay://pair?code=ABC234&code=XYZ789',
        'ABC2347',
      ]) {
        expect(parsePairingCode(input), isNull);
      }
    },
  );
  Future<void> mount(
    WidgetTester tester,
    DashboardFake service, {
    required bool caregiver,
    ThemeData? theme,
    Future<String?> Function(BuildContext)? scanCode,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? GabayTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardPairingCard(
              caregiver: caregiver,
              service: service,
              scanCode: scanCode,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> cleanup(WidgetTester tester, DashboardFake service) async {
    await tester.pumpWidget(const SizedBox());
    await service.close();
  }

  testWidgets(
    'navigator code is prominent, accessible, copyable and QR stays readable at large scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      for (final theme in [GabayTheme.lightTheme, GabayTheme.darkTheme]) {
        final service = DashboardFake();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: DashboardPairingCard(
                    caregiver: false,
                    service: service,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(Checkbox));
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Show my pairing code'));
        await tester.tap(find.text('Show my pairing code'));
        await tester.pumpAndSettle();
        expect(find.text('ABC234'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Pairing code A B C 2 3 4'),
          findsOneWidget,
        );
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        await tester.ensureVisible(find.text('Copy code'));
        await tester.tap(find.text('Copy code'));
        await tester.pumpAndSettle();
        expect(copied, 'ABC234');
        expect(find.text('Pairing code copied.'), findsOneWidget);
        expect(find.text('Read code aloud'), findsOneWidget);
        await tester.ensureVisible(find.text('QR code'));
        await tester.tap(find.text('QR code'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(QrImageView));
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsLabel(
            'QR for this pairing code. Caregiver: use Scan QR in AKAY.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await cleanup(tester, service);
      }
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      semantics.dispose();
    },
  );
  testWidgets(
    'caregiver entry validates input, activates pairing and handles multiple Navigators',
    (tester) async {
      final service = DashboardFake();
      await mount(tester, service, caregiver: true);
      await tester.tap(find.text('Add / Pair New Navigator'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pair Navigator'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Enter the six-character code'),
        findsOneWidget,
      );
      expect(service.redeemed, isNull);
      await tester.enterText(find.byType(TextField), 'abc234');
      await tester.tap(find.text('Pair Navigator'));
      await tester.pumpAndSettle();
      expect(service.redeemed, 'ABC234');
      expect(find.text('✓ Paired · Access active'), findsOneWidget);
      expect(service.method, 'alphanumeric');
      service.updates.add([
        connection('one', status: 'active'),
        connection('two', status: 'active'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Navigator one'), findsOneWidget);
      expect(find.text('Navigator two'), findsOneWidget);
      expect(find.text('✓ Paired · Access active'), findsNWidgets(2));
      expect(
        find.textContaining('Successfully paired with Navigator two'),
        findsWidgets,
      );
      await cleanup(tester, service);
    },
  );
  testWidgets(
    'QR scanning uses the same request flow without camera dependency in tests',
    (tester) async {
      final service = DashboardFake();
      await mount(
        tester,
        service,
        caregiver: true,
        scanCode: (_) async => 'akay://pair?code=ABC234',
      );
      await tester.tap(find.text('Add / Pair New Navigator'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan Navigator QR'));
      await tester.pumpAndSettle();
      expect(service.redeemed, 'ABC234');
      expect(find.text('✓ Paired · Access active'), findsOneWidget);
      expect(service.method, 'qr_code');
      await cleanup(tester, service);
    },
  );
  testWidgets(
    'Navigator approval stays explicit and confirms the paired caregiver',
    (tester) async {
      final service = DashboardFake()..rows = [connection('one')];
      await mount(tester, service, caregiver: false);
      await tester.ensureVisible(find.text('Review and allow'));
      await tester.tap(find.text('Review and allow'));
      await tester.pumpAndSettle();
      expect(service.decided, isNull);
      expect(
        find.textContaining('This caregiver can view your profile'),
        findsOneWidget,
      );
      await tester.tap(find.text('Allow caregiver'));
      await tester.pumpAndSettle();
      expect(service.decided, 'accepted');
      expect(
        find.textContaining('Successfully paired with Caregiver one'),
        findsWidgets,
      );
      await cleanup(tester, service);
    },
  );
}
