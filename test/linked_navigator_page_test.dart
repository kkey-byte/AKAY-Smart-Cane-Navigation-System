import 'package:app_mobile/models/pairing.dart';
import 'package:app_mobile/pages/caregiver/linked_navigator_cane_page.dart';
import 'package:app_mobile/services/pairing_service.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Connections extends PairingService {
  String? removed;
  bool fail = false;
  final rows = [
    const PairingConnection(
      id: 'link-one',
      navigatorUid: 'firebase-one',
      navigatorUserId: 'user-one',
      caregiverUid: 'caregiver',
      navigatorName: 'Test Navigator',
      caregiverName: 'Test Caregiver',
      status: 'active',
    ),
    const PairingConnection(
      id: 'link-two',
      navigatorUid: 'firebase-two',
      navigatorUserId: 'user-two',
      caregiverUid: 'caregiver',
      navigatorName: 'Second Navigator',
      caregiverName: 'Test Caregiver',
      status: 'pending',
    ),
    const PairingConnection(
      id: 'old-link',
      navigatorUid: 'firebase-old',
      caregiverUid: 'caregiver',
      navigatorName: 'Old Navigator',
      caregiverName: 'Test Caregiver',
      status: 'revoked',
    ),
  ];
  @override
  Stream<List<PairingConnection>> watchConnections() => Stream.value(rows);
  @override
  Future<void> revoke(String id) async {
    if (fail) throw StateError('Synthetic failure');
    removed = id;
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Connections service, {
  bool large = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: large ? GabayTheme.darkTheme : GabayTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
        child: child!,
      ),
      home: LinkedNavigatorCanePage(service: service),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Connection parses navigator user ID and picture from existing response',
    () {
      final row = PairingConnection.fromJson({
        'id': 'link',
        'navigator_uid': 'firebase',
        'navigator_id': 'user-id',
        'navigator_picture': 'https://example.test/photo.png',
        'caregiver_uid': 'caregiver',
        'navigator_name': 'Test',
        'caregiver_name': 'Caregiver',
        'status': 'active',
      });
      expect(row.navigatorUserId, 'user-id');
      expect(row.navigatorPicture, 'https://example.test/photo.png');
    },
  );

  testWidgets(
    'Lists linked navigators and removes only the confirmed connection',
    (tester) async {
      final service = _Connections();
      await _mount(tester, service);
      expect(find.text('Linked Navigator'), findsOneWidget);
      expect(find.text('User ID: user-one'), findsOneWidget);
      expect(find.text('Old Navigator'), findsNothing);
      expect(find.textContaining('Connected'), findsOneWidget);
      expect(find.textContaining('Pending approval'), findsOneWidget);
      expect(find.text('Redeem invitation'), findsNothing);
      await tester.tap(find.byTooltip('Remove Test Navigator'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.removed, isNull);
      await tester.tap(find.byTooltip('Remove Test Navigator'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(service.removed, 'link-one');
      expect(find.text('Test Navigator'), findsNothing);
      expect(find.text('Second Navigator'), findsOneWidget);
    },
  );

  testWidgets(
    'Failed removal retains navigator and narrow large-text layout remains usable',
    (tester) async {
      tester.view.physicalSize = const Size(374, 750);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _Connections()..fail = true;
      await _mount(tester, service, large: true);
      await tester.tap(find.byTooltip('Remove Test Navigator'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Test Navigator'), findsOneWidget);
      expect(
        find.text('Could not remove this connection. Please try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
