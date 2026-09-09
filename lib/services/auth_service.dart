import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';

/// Result returned by [AuthService] after a successful auth call.
class AuthResult {
  const AuthResult({
    required this.user,
    this.token,
  });

  final AppUser user;
  final String? token;
}

/// Thrown when Firebase or the Postgres sync layer rejects the request.
class AuthException implements Exception {
  AuthException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

/// Split-auth client:
/// 1) Firebase Auth for credentials
/// 2) `app_mobile_backend` → PostgreSQL `Users` for profile/role
class AuthService {
  AuthService({
    http.Client? client,
    String? baseUrl,
    FirebaseAuth? firebaseAuth,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  static final AuthService instance = AuthService();

  final http.Client _client;
  final String _baseUrl;
  final FirebaseAuth _firebaseAuth;

  /// Step A: Firebase createUser → Step B: Postgres profile sync.
  Future<AuthResult> register({
    required String email,
    required String password,
    required UserRole role,
    String? name,
    String? phone,
    String? profilePicture,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    late final UserCredential credential;
    try {
      credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // Account exists in Firebase from a previous half-finished signup —
      // sign in and continue syncing the Postgres profile.
      if (e.code == 'email-already-in-use') {
        try {
          credential = await _firebaseAuth.signInWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
        } on FirebaseAuthException catch (signInError) {
          throw AuthException(
            _mapFirebaseError(signInError),
            code: signInError.code,
          );
        }
      } else {
        throw AuthException(_mapFirebaseError(e), code: e.code);
      }
    }

    final firebaseUser = credential.user;
    if (firebaseUser == null || firebaseUser.uid.isEmpty) {
      throw AuthException('Firebase did not return a user after sign-up.');
    }

    final firebaseUid = firebaseUser.uid;

    // Sync profile to Postgres. Password is sent so the API can store a bcrypt
    // hash (login still uses Firebase Auth as the source of truth).
    final payload = <String, dynamic>{
      'firebase_uid': firebaseUid,
      'firebaseUid': firebaseUid, // camelCase alias for compatibility
      'email': normalizedEmail,
      'password': password,
      'role': role.backendValue, // 'caregiver' | 'visually_impaired'
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (profilePicture != null && profilePicture.trim().isNotEmpty)
        'profile_picture': profilePicture.trim(),
    };

    debugPrint('AuthService: POST $_baseUrl/auth/register');
    debugPrint(
      'AuthService: firebase_uid=$firebaseUid email=$normalizedEmail role=${role.backendValue}',
    );

    try {
      return await _postAuth('/auth/register', payload);
    } on AuthException catch (e) {
      // Profile already in Postgres — treat as success and load it.
      if (e.statusCode == 409) {
        return _postAuth('/auth/login', {'firebase_uid': firebaseUid});
      }
      // Only roll back Firebase when the DB profile was NOT created.
      if (e.statusCode == null || e.statusCode! >= 500) {
        try {
          await firebaseUser.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Signs out of Firebase Auth (used when Postgres role lookup fails).
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// Step A: Firebase signIn → Step B: SELECT profile by firebase_uid.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    late final UserCredential credential;
    try {
      credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e), code: e.code);
    }

    final firebaseUid = credential.user?.uid;
    if (firebaseUid == null || firebaseUid.isEmpty) {
      throw AuthException('Firebase did not return a user after login.');
    }

    debugPrint('AuthService: loading Postgres profile for firebase_uid=$firebaseUid');

    return _postAuth('/auth/login', {
      'firebase_uid': firebaseUid,
      'firebaseUid': firebaseUid,
    });
  }

  Future<AuthResult> _postAuth(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');
    final encoded = jsonEncode(payload);

    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: encoded,
          )
          .timeout(const Duration(seconds: 20));
    } on Exception catch (e) {
      debugPrint('AuthService network error: $e');
      throw AuthException(
        'Unable to reach the auth API at $_baseUrl.\n'
        '1) Start app_mobile_backend: npm start\n'
        '2) Confirm DB settings in app_mobile_backend/.env\n'
        '3) On a physical phone, pass your PC IP via API_BASE_URL',
      );
    }

    debugPrint('AuthService: $path → ${response.statusCode} ${response.body}');

    final body = _decodeBody(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (body['message'] ??
              body['error'] ??
              'Authentication failed (${response.statusCode})')
          .toString();
      throw AuthException(message, statusCode: response.statusCode);
    }

    final userRaw = body['user'] ?? body['data'] ?? body;
    try {
      final user = AppUser.fromJson(_asStringKeyMap(userRaw));
      final token =
          (body['token'] ?? body['access_token'] ?? payload['firebase_uid'])
              ?.toString();
      return AuthResult(user: user, token: token);
    } on FormatException catch (e) {
      throw AuthException(e.message, statusCode: response.statusCode);
    }
  }

  Map<String, dynamic> _asStringKeyMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Invalid user payload from server.');
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    return switch (e.code) {
      'email-already-in-use' => 'This email is already registered.',
      'weak-password' => 'Password is too weak. Use at least 6 characters.',
      'invalid-email' => 'Enter a valid email address.',
      'user-not-found' => 'No account found for this email.',
      'wrong-password' => 'Incorrect password. Please try again.',
      'invalid-credential' => 'Email or password is incorrect.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'network-request-failed' =>
        'Network error. Check your internet connection.',
      _ => e.message ?? 'Authentication failed (${e.code}).',
    };
  }

  Map<String, dynamic> _decodeBody(String raw) {
    if (raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'data': decoded};
    } on FormatException {
      return {'message': raw};
    }
  }
}
