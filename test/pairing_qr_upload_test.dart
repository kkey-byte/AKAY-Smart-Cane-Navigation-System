import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/shared/dashboard_pairing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dashboard_pairing_test.dart' show DashboardFake;

void main() {
  for (final result in ['akay://pair?code=ABC234', 'invalid', null]) {
    testWidgets('QR image result $result preserves pairing validation', (
      tester,
    ) async {
      final service = DashboardFake();
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardPairingCard(
                caregiver: true,
                service: service,
                uploadCode: () async => result,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add / Pair New Navigator'));
      await tester.pumpAndSettle();
      expect(find.text('Scan Navigator QR'), findsOneWidget);
      await tester.tap(find.text('Upload QR image'));
      await tester.pumpAndSettle();
      if (result?.startsWith('akay://') == true) {
        expect(service.redeemed, 'ABC234');
        expect(service.method, 'qr_code');
        expect(find.byType(AlertDialog), findsNothing);
      } else {
        expect(service.redeemed, isNull);
        expect(find.byType(AlertDialog), findsOneWidget);
        if (result != null) {
          expect(
            find.text('Enter the six-character code shown by the Navigator.'),
            findsOneWidget,
          );
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await service.close();
    });
  }
}
