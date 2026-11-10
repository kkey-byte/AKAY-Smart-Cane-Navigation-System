import 'package:app_mobile/models/user_role.dart';
import 'package:app_mobile/services/app_session_service.dart';
import 'package:app_mobile/services/live_location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'live transaction keeps newest capture even when receipt order reverses',
    () {
      final latest = DateTime(2026, 1, 1);
      final current = {'timestamp': latest.millisecondsSinceEpoch};
      expect(
        LiveLocationService.acceptsSample(
          current,
          latest.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
      );
      expect(LiveLocationService.acceptsSample(current, latest), isFalse);
      expect(
        LiveLocationService.acceptsSample(
          current,
          latest.add(const Duration(seconds: 1)),
        ),
        isTrue,
      );
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  final session = AppSessionService.instance;
  late LiveLocationService service;
  late String uid;
  late String email;
  late List<String> writes;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'navigator-a';
    email = 'navigator-a@example.test';
    writes = [];
    session.isLoggedIn = true;
    session.role = UserRole.navigator;
    session.email = email;
    service = LiveLocationService.forTest(
      () => uid,
      () => email,
      (id, _) async => writes.add(id),
    )..sharingEnabled = true;
  });

  Future<void> publish(String owner) =>
      service.publish(deviceId: 'phone_$owner', latitude: 10, longitude: 20);

  test('navigator GPS stays owned by the recording account', () async {
    await publish('navigator-a');
    expect(writes, ['phone_navigator-a']);
    uid = 'navigator-b';
    email = session.email = 'navigator-b@example.test';
    await publish('navigator-a');
    expect(writes, ['phone_navigator-a']);
    await publish('navigator-b');
    expect(writes, ['phone_navigator-a', 'phone_navigator-b']);
  });

  test('caregiver cannot publish even with a retained sharing flag', () async {
    uid = 'caregiver';
    email = session.email = 'caregiver@example.test';
    session.role = UserRole.caregiver;
    await publish('caregiver');
    await publish('navigator-a');
    expect(writes, isEmpty);
  });

  test(
    'Firebase account transition cannot publish under old local session',
    () async {
      uid = 'caregiver';
      email = 'caregiver@example.test';
      await publish('caregiver');
      expect(writes, isEmpty);
    },
  );

  test(
    'new login disables GPS sharing even for the same saved identity',
    () async {
      await session.loginSession(
        userEmail: email,
        userRole: UserRole.navigator,
        id: 'synthetic-sql-id',
      );
      LiveLocationService.instance.sharingEnabled = true;
      await session.loginSession(
        userEmail: email,
        userRole: UserRole.caregiver,
        id: 'synthetic-sql-id',
      );
      expect(LiveLocationService.instance.sharingEnabled, isFalse);
    },
  );
}
