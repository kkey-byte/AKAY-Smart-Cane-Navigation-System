import 'package:app_mobile/models/pairing.dart';
import 'package:app_mobile/pages/visually_impaired/vi_caregivers_page.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dashboard_pairing_test.dart' show DashboardFake, connection;

class _Caregivers extends DashboardFake {
  int watches = 0;
  @override
  Stream<List<PairingConnection>> watchConnections() {
    watches++;
    return super.watchConnections();
  }

  String? revoked;
  @override
  Future<void> revoke(String id) async => revoked = id;
}

void main() {
  testWidgets(
    'Caregivers contains pairing and confirmed disconnect without the old Connections screen',
    (tester) async {
      final service = _Caregivers()
        ..rows = [connection('one', status: 'active')];
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          builder: (context, child) => NotificationListener<ScrollNotification>(
            onNotification: (n) {
              debugPrint(
                'SCROLL ${n.runtimeType} ${n.depth} ${n.metrics.pixels}',
              );
              return false;
            },
            child: child!,
          ),
          home: ViCaregiversPage(service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Caregivers'), findsOneWidget);
      expect(find.text('Caregiver Connections'), findsOneWidget);
      expect(find.text('Manage connections and access'), findsNothing);
      expect(find.text('Create invitation'), findsNothing);
      expect(find.text('Smart Canes'), findsNothing);
      final disconnect = find.byTooltip('Disconnect Caregiver one');
      await tester.ensureVisible(disconnect);
      await tester.tap(disconnect);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.revoked, isNull);
      await tester.tap(disconnect);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Disconnect'));
      await tester.pumpAndSettle();
      expect(service.revoked, 'one');
      expect(find.text('Caregiver one'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await service.close();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'pull refresh works with short content and keeps consent unchanged',
    (tester) async {
      final service = _Caregivers();
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: ViCaregiversPage(service: service),
        ),
      );
      await tester.pumpAndSettle();
      service.rows = [connection('new', status: 'active')];
      final gesture = await tester.startGesture(
        tester.getTopLeft(find.byType(ListView)) + const Offset(30, 40),
      );
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 50));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(service.watches, 2);
      expect(find.text('Caregiver new'), findsOneWidget);
      await tester.tap(find.text('Invite a Caregiver'));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      expect(
        tester
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .mounted,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      await service.close();
      expect(tester.takeException(), isNull);
    },
  );
}
