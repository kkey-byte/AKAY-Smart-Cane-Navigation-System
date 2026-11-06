import 'package:app_mobile/models/pairing.dart';
import 'package:app_mobile/pages/caregiver/navigator_health_details_page.dart';
import 'package:app_mobile/services/pairing_service.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Links extends PairingService {
  @override
  Stream<List<PairingConnection>> watchConnections() => Stream.value([
    for (final id in ['First', 'Second'])
      PairingConnection(
        id: id,
        navigatorUid: id,
        caregiverUid: 'caregiver',
        navigatorName: '$id Navigator',
        caregiverName: 'Caregiver',
        status: 'active',
      ),
    const PairingConnection(
      id: 'old',
      navigatorUid: 'old',
      caregiverUid: 'caregiver',
      navigatorName: 'Revoked Navigator',
      caregiverName: 'Caregiver',
      status: 'revoked',
    ),
  ]);
}

void main() {
  testWidgets(
    'Caregiver selects real linked identities without showing own health record',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.darkTheme,
          home: NavigatorHealthDetailsPage(service: _Links()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('First Navigator'), findsOneWidget);
      expect(find.text('Health information not available'), findsOneWidget);
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
      expect(tester.takeException(), isNull);
    },
  );
}
