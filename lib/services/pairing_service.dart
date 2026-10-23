import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pairing.dart';
import 'secure_api.dart';

class PairingService {
  PairingService({SecureApi? api}) : api = api ?? SecureApi.instance;
  static final instance = PairingService();
  final SecureApi api;
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
  Future<Map<String, dynamic>> generatePairing(String method) async {
    final uid = currentUid;
    if (uid == null) throw StateError('Sign in to create a pairing code.');
    final preferences = await SharedPreferences.getInstance();
    if (currentUid != uid) throw StateError('Account changed.');
    final key = 'akay_pairing_app_instance_$uid';
    final data = await api.request('POST', '/v2/pairings/codes', {
      'pairing_method': method,
      'authorize_pairing': true,
      if (preferences.getString(key) != null)
        'device_id': preferences.getString(key),
    });
    if (currentUid != uid) throw StateError('Account changed.');
    final device = (data['pairing'] as Map?)?['device_id'];
    if (device is String) await preferences.setString(key, device);
    return data;
  }

  Future<void> redeemPairing(String code, String method) async {
    await api.request('POST', '/v2/pairings/redeem', {
      'code': code.trim(),
      'pairing_method': method,
    });
  }

  Future<List<PairingConnection>> connections() async {
    final data = await api.request('GET', '/v2/connections');
    return (data['connections'] as List)
        .map(
          (e) =>
              PairingConnection.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Stream<List<PairingConnection>> watchConnections() => api
      .watchGet('/v2/connections')
      .map(
        (data) => (data['connections'] as List)
            .map(
              (row) => PairingConnection.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList(),
      );
  Future<Map<String, dynamic>> invite() =>
      api.request('POST', '/v2/invitations');
  Future<void> redeem(String code) async {
    await api.request('POST', '/v2/invitations/redeem', {'code': code.trim()});
  }

  Future<void> decide(String id, bool accept) async {
    await api.request(
      'POST',
      '/v2/connections/${Uri.encodeComponent(id)}/${accept ? 'accept' : 'reject'}',
    );
  }

  Future<void> revoke(String id) async {
    await api.request('DELETE', '/v2/connections/${Uri.encodeComponent(id)}');
  }

  Future<List<RegisteredCane>> devices() async {
    final data = await api.request('GET', '/v2/devices');
    return (data['devices'] as List)
        .map(
          (e) => RegisteredCane.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> claim(String id, String claimCode) async {
    await api.request('POST', '/v2/devices/claim', {
      'deviceId': id.trim(),
      'claimCode': claimCode.trim(),
    });
  }

  Future<void> assign(String id) async {
    await api.request('POST', '/v2/devices/${Uri.encodeComponent(id)}/assign');
  }

  Future<void> release(String id, {bool ownership = false}) async {
    await api.request(
      'DELETE',
      '/v2/devices/${Uri.encodeComponent(id)}/${ownership ? 'ownership' : 'assignment'}',
    );
  }

  Future<Map<String, dynamic>> transfer(String id, String uid) => api.request(
    'POST',
    '/v2/devices/${Uri.encodeComponent(id)}/transfer',
    {'navigatorUid': uid.trim()},
  );
  Future<void> acceptTransfer(String code) async {
    await api.request('POST', '/v2/transfers/accept', {'code': code.trim()});
  }

  Stream<Map<String, dynamic>> watchSnapshot(String uid) =>
      api.watchGet('/v2/navigators/${Uri.encodeComponent(uid)}/snapshot');
}
