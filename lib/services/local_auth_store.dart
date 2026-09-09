import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';
import 'auth_service.dart';

/// Local stand-in for the PostgreSQL `Users` table while the API is offline.
/// Stores the same fields your backend schema expects.
class LocalAuthStore {
  LocalAuthStore._();

  static final LocalAuthStore instance = LocalAuthStore._();

  static const _usersKey = 'local_users_v1';

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usersKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveUsers(List<Map<String, dynamic>> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, jsonEncode(users));
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    required UserRole role,
    String? name,
    String? phone,
    String? profilePicture,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final users = await _loadUsers();

    final exists = users.any(
      (u) => (u['email'] as String?)?.toLowerCase() == normalizedEmail,
    );
    if (exists) {
      throw AuthException('An account with this email already exists.');
    }

    final now = DateTime.now().toUtc();
    final userId = _newUuid();

    final record = <String, dynamic>{
      'user_id': userId,
      'name': name,
      'email': normalizedEmail,
      'password': password, // hashed on a real backend; plain for local only
      'role': role.backendValue,
      'phone': phone,
      'profile_picture': profilePicture,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    users.add(record);
    await _saveUsers(users);

    return AuthResult(
      user: AppUser.fromJson(record),
      token: 'local_$userId',
    );
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    await _ensureSeedUser();

    final normalizedEmail = email.trim().toLowerCase();
    final users = await _loadUsers();

    Map<String, dynamic>? match;
    for (final user in users) {
      if ((user['email'] as String?)?.toLowerCase() == normalizedEmail) {
        match = user;
        break;
      }
    }

    if (match == null || match['password'] != password) {
      throw AuthException(
        'The email or password is not registered. '
        'Create an account on Sign up, or use test@gmail.com / 123456.',
      );
    }

    return AuthResult(
      user: AppUser.fromJson(match),
      token: 'local_${match['user_id']}',
    );
  }

  /// Seeds the previous demo account so existing login habits still work.
  Future<void> _ensureSeedUser() async {
    final users = await _loadUsers();
    final hasDemo = users.any(
      (u) => (u['email'] as String?)?.toLowerCase() == 'test@gmail.com',
    );
    if (hasDemo) return;

    final now = DateTime.now().toUtc().toIso8601String();
    users.add({
      'user_id': 'local-demo-caregiver',
      'name': null,
      'email': 'test@gmail.com',
      'password': '123456',
      'role': UserRole.caregiver.backendValue,
      'phone': null,
      'profile_picture': null,
      'created_at': now,
      'updated_at': now,
    });
    await _saveUsers(users);
  }

  /// Simple UUID-ish id for local rows (not cryptographically strong).
  String _newUuid() {
    final millis = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final random = (millis.hashCode.abs()).toRadixString(16).padLeft(8, '0');
    return '$millis-$random';
  }
}
