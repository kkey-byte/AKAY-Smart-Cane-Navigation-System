import 'dart:async';
import 'dart:convert';
import 'package:app_mobile/models/pairing.dart';
import 'package:app_mobile/pages/shared/pairing_management_page.dart';
import 'package:app_mobile/services/pairing_service.dart';
import 'package:app_mobile/services/secure_api.dart';
import 'package:app_mobile/theme/gabay_theme.dart';
import 'package:app_mobile/widgets/shared/navigator_data_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakePairing extends PairingService {
  final updates = StreamController<List<PairingConnection>>.broadcast();
  final readings = StreamController<Map<String, dynamic>>.broadcast();
  List<PairingConnection> rows = [];
  String? decided;
  @override
  String? get currentUid => 'synthetic-navigator';
  @override
  Stream<List<PairingConnection>> watchConnections() => Stream.multi((c) {
    c.add(rows);
    final sub = updates.stream.listen(c.add, onError: c.addError);
    c.onCancel = sub.cancel;
  });
  @override
  Future<List<RegisteredCane>> devices() async => [];
  @override
  Future<void> decide(String id, bool accept) async {
    decided = accept ? 'accepted' : 'rejected';
  }

  @override
  Stream<Map<String, dynamic>> watchSnapshot(String uid) => Stream.multi((c) {
    c.add(snapshot(uid));
    final sub = readings.stream.listen(c.add, onError: c.addError);
    c.onCancel = sub.cancel;
  });
  Map<String, dynamic> snapshot(String uid) => {
    'navigator': {'name': uid, 'uid': uid},
    'phoneLocation': null,
    'alerts': [],
    'devices': [
      {
        'id': 'cane-$uid',
        'serial': 'Serial $uid',
        'assignment_id': 'assignment-$uid',
        'sampled_at': null,
        'battery': null,
        'status': null,
        'latitude': null,
        'longitude': null,
      },
    ],
  };
  Future<void> close() async {
    await updates.close();
    await readings.close();
  }
}

void main() {
  test(
    'secure API sends an ID token and ignores stored UID-like credentials',
    () async {
      final api = SecureApi(
        idToken: () async => 'synthetic-token',
        bases: ['http://example.test/api'],
        revision: () => 0,
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer synthetic-token');
          return http.Response('{"connections":[]}', 200);
        }),
      );
      expect(
        (await api.request('GET', '/v2/connections'))['connections'],
        isEmpty,
      );
    },
  );
  test(
    'secure API requires sign-in and invalidates delayed account responses',
    () async {
      final api = SecureApi(
        idToken: () async => null,
        bases: ['http://example.test'],
        revision: () => 0,
      );
      await expectLater(
        api.request('GET', '/v2/connections'),
        throwsA(isA<SecureApiException>()),
      );
      var revision = 0;
      final response = Completer<http.Response>();
      final delayed = SecureApi(
        idToken: () async => 'synthetic-token',
        bases: ['http://example.test'],
        revision: () => revision,
        client: MockClient((_) => response.future),
      );
      final pending = delayed.request('GET', '/v2/connections');
      await Future<void>.delayed(Duration.zero);
      revision++;
      response.complete(http.Response('{}', 200));
      await expectLater(pending, throwsA(isA<SecureApiException>()));
    },
  );
  test('mutation is not retried after an uncertain network outcome', () async {
    var calls = 0;
    final api = SecureApi(
      idToken: () async => 'synthetic-token',
      bases: ['http://one.test', 'http://two.test'],
      revision: () => 0,
      client: MockClient((_) async {
        calls++;
        throw http.ClientException('Synthetic failure');
      }),
    );
    await expectLater(
      api.request('POST', '/v2/invitations/redeem', {'code': 'synthetic'}),
      throwsA(isA<SecureApiException>()),
    );
    expect(calls, 1);
  });
  testWidgets(
    'pending navigator request names requester, explains sharing and confirms consent',
    (tester) async {
      final service = FakePairing()
        ..rows = [
          const PairingConnection(
            id: 'request',
            navigatorUid: 'synthetic-navigator',
            caregiverUid: 'caregiver',
            navigatorName: 'Navigator',
            caregiverName: 'Synthetic Caregiver',
            status: 'pending',
          ),
        ];
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: PairingManagementPage(caregiver: false, service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetic Caregiver'), findsOneWidget);
      expect(
        find.textContaining('current and previous phone GPS tracks'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Accept access'));
      await tester.tap(find.text('Accept access'));
      await tester.pumpAndSettle();
      expect(service.decided, isNull);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(service.decided, 'accepted');
      await tester.pumpWidget(const SizedBox());
      await service.close();
    },
  );
  testWidgets(
    'changing monitored navigator hides previous cane and revoked readings',
    (tester) async {
      final service = FakePairing();
      Widget page(String uid) => MaterialApp(
        theme: GabayTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: NavigatorDataCard(navigatorUid: uid, service: service),
          ),
        ),
      );
      await tester.pumpWidget(page('navigator-a'));
      await tester.pumpAndSettle();
      expect(find.text('Device ID: cane-navigator-a'), findsOneWidget);
      await tester.pumpWidget(page('navigator-b'));
      await tester.pumpAndSettle();
      expect(find.text('Device ID: cane-navigator-a'), findsNothing);
      expect(find.text('Device ID: cane-navigator-b'), findsOneWidget);
      service.readings.addError(
        const SecureApiException('Access revoked', status: 403),
      );
      await tester.pumpAndSettle();
      expect(find.text('Device ID: cane-navigator-b'), findsNothing);
      expect(find.textContaining('Previous readings hidden'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await service.close();
    },
  );
  testWidgets(
    'empty pairing screen supports large text with no fabricated devices',
    (tester) async {
      final service = FakePairing();
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: GabayTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: PairingManagementPage(caregiver: true, service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No connections yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await service.close();
    },
  );
  test('missing and stale readings stay unknown', () {
    final d = CaneReading.fromJson(
      jsonDecode(
            '{"id":"cane","serial":"synthetic","assignment_id":"a","latitude":100}',
          )
          as Map<String, dynamic>,
    );
    expect(d.latitude, isNull);
    expect(d.battery, isNull);
    expect(d.fresh(DateTime.now()), isFalse);
  });
}
