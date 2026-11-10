import 'package:app_mobile/models/pairing.dart';
import 'package:app_mobile/pages/visually_impaired/vi_caregivers_page.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:app_mobile/widgets/akay_logo_data.dart';
import 'package:app_mobile/widgets/profile/linked_navigator_photo.dart';
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
  test('Connection reads an optional caregiver photo without requiring it', () {
    final json = {
      'id': 'one',
      'navigator_uid': 'navigator',
      'caregiver_uid': 'caregiver',
      'navigator_name': 'Navigator',
      'caregiver_name': 'Caregiver',
      'status': 'active',
      'caregiver_picture': 'https://example.test/avatar.png',
    };
    expect(
      PairingConnection.fromJson(json).caregiverPicture,
      'https://example.test/avatar.png',
    );
    json.remove('caregiver_picture');
    expect(PairingConnection.fromJson(json).caregiverPicture, isNull);
  });
  for (final dark in [false, true]) {
    testWidgets(
      'Caregiver photo renders in the responsive connection card dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = _Caregivers()
          ..rows = [
            PairingConnection(
              id: 'photo',
              navigatorUid: 'navigator',
              caregiverUid: 'caregiver',
              navigatorName: 'Navigator',
              caregiverName: 'Test Caregiver With A Long Name',
              status: 'active',
              caregiverPicture:
                  'data:image/png;base64,${base64Encode(akayLogoBytes)}',
            ),
          ];
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? GabayTheme.darkTheme : GabayTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: ViCaregiversPage(service: service),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LinkedNavigatorPhoto), findsOneWidget);
        final image = tester.widget<Image>(
          find.descendant(
            of: find.byType(LinkedNavigatorPhoto),
            matching: find.byType(Image),
          ),
        );
        expect(
          (image.image as MemoryImage).bytes,
          orderedEquals(akayLogoBytes),
        );
        await tester.ensureVisible(
          find.byTooltip('Disconnect Test Caregiver With A Long Name'),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await service.close();
      },
    );
  }
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
  testWidgets('pull refresh works and pairing no longer requires a checkbox', (
    tester,
  ) async {
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
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Share only with a trusted caregiver.'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Show my pairing code'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.ensureVisible(find.text('Show my pairing code'));
    await tester.tap(find.text('Show my pairing code'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Copy code'), findsNothing);
    expect(find.text('Read code aloud'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(
      tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .mounted,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    await service.close();
    expect(tester.takeException(), isNull);
  });
}
