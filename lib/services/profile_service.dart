import 'secure_api.dart';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/patient_profile.dart';
import 'app_session_service.dart';

/// Progressive profile completion: Users + PatientProfiles via `/api/profile`.
class ProfileService {
  ProfileService({
    http.Client? client,
    String? baseUrl,
    String? Function()? firebaseUid,
    Future<String?> Function()? idToken,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? ApiConfig.baseUrl,
       _usesDefaultBase = baseUrl == null,
       _firebaseUid =
           firebaseUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _idToken =
           idToken ??
           (() =>
               FirebaseAuth.instance.currentUser?.getIdToken() ??
               Future.value());

  static final ProfileService instance = ProfileService();

  int _profileWriteRevision = 0;
  final Future<String?> Function() _idToken;
  final http.Client _client;
  final String _baseUrl;
  final bool _usesDefaultBase;
  String get _effectiveBase =>
      _usesDefaultBase ? (SecureApi.preferredBase ?? _baseUrl) : _baseUrl;
  final String? Function() _firebaseUid;

  Future<ProfileBundle> fetchProfile() async {
    final writeRevision = _profileWriteRevision;
    final session = AppSessionService.instance;
    final revision = session.identityRevision;
    if (!session.isLoggedIn) throw ProfileException('Please sign in again.');
    final firebaseUid = _firebaseUid();
    final params = <String, String>{
      if (session.userId != null && session.userId!.isNotEmpty)
        'userId': session.userId!,
      if (firebaseUid != null && firebaseUid.isNotEmpty)
        'firebaseUid': firebaseUid,
    };

    if (params.isEmpty) {
      throw ProfileException('No signed-in user to load profile for.');
    }

    final uri = Uri.parse(
      '$_effectiveBase/profile',
    ).replace(queryParameters: params);
    if (kReleaseMode && uri.scheme != 'https') {
      throw ProfileException(
        'HTTPS is required. Configure a secure API endpoint.',
      );
    }
    final response = await _client
        .get(uri, headers: await _headers(revision))
        .timeout(const Duration(seconds: 15));

    final body = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProfileException(
        (body['message'] ?? 'Failed to load profile').toString(),
        statusCode: response.statusCode,
      );
    }

    if (writeRevision != _profileWriteRevision) {
      throw ProfileException('Profile changed while loading. Please refresh.');
    }
    final bundle = ProfileBundle.fromJson(body);
    if (!session.isLoggedIn || session.identityRevision != revision) {
      throw ProfileException('Account changed. Please reload your profile.');
    }
    if (session.userId != null && bundle.userId != session.userId) {
      throw ProfileException('Profile identity could not be verified.');
    }
    await session.updateProfileCache(
      expectedIdentityRevision: revision,
      name: bundle.name ?? '',
      phone: bundle.phone ?? '',
      profilePicture: bundle.profilePicture ?? '',
      profileComplete: bundle.profileComplete,
    );
    return bundle;
  }

  Future<ProfileBundle> saveProfile({
    required String name,
    required String phone,
    String? profilePicture,
    required PatientProfile patient,
  }) async {
    final session = AppSessionService.instance;
    final revision = session.identityRevision;
    if (!session.isLoggedIn) throw ProfileException('Please sign in again.');
    final firebaseUid = _firebaseUid();

    final payload = <String, dynamic>{
      if (session.userId != null && session.userId!.isNotEmpty)
        'userId': session.userId,
      if (firebaseUid != null && firebaseUid.isNotEmpty)
        'firebaseUid': firebaseUid,
      'name': name.trim(),
      'phone': phone.trim(),
      if (profilePicture != null && profilePicture.trim().isNotEmpty)
        'profilePicture': profilePicture.trim(),
      ...patient.toJson(),
    };

    debugPrint(
      'ProfileService.saveProfile → keys=${payload.keys.toList()} '
      'hasPicture=${payload.containsKey('profilePicture')} '
      'pictureLen=${(payload['profilePicture'] as String?)?.length ?? 0}',
    );

    final uri = Uri.parse('$_effectiveBase/profile');
    if (kReleaseMode && uri.scheme != 'https') {
      throw ProfileException(
        'HTTPS is required. Configure a secure API endpoint.',
      );
    }
    final response = await _client
        .put(uri, headers: await _headers(revision), body: jsonEncode(payload))
        .timeout(const Duration(seconds: 20));

    debugPrint(
      'ProfileService.saveProfile ← ${response.statusCode} '
      '(body ${response.body.length} chars)',
    );

    final body = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProfileException(
        (body['message'] ?? 'Failed to save profile').toString(),
        statusCode: response.statusCode,
      );
    }

    _profileWriteRevision++;
    final bundle = ProfileBundle.fromJson(body);
    if (!session.isLoggedIn || session.identityRevision != revision) {
      throw ProfileException('Account changed. Please reload your profile.');
    }
    if (session.userId != null && bundle.userId != session.userId) {
      throw ProfileException('Profile identity could not be verified.');
    }
    await session.updateProfileCache(
      expectedIdentityRevision: revision,
      name: bundle.name ?? '',
      phone: bundle.phone ?? '',
      profilePicture: bundle.profilePicture ?? '',
      profileComplete: bundle.profileComplete,
    );
    return bundle;
  }

  /// Encodes image bytes as a data URL for reliable Postgres TEXT storage.
  /// Avoids Firebase Storage / CORS issues that were dropping pictures.
  String encodeProfilePictureDataUrl(Uint8List bytes) {
    final b64 = base64Encode(bytes);
    return 'data:image/jpeg;base64,$b64';
  }

  Future<Map<String, String>> _headers(int revision) async {
    final token = await _idToken();
    final session = AppSessionService.instance;
    if (token == null ||
        token.isEmpty ||
        !session.isLoggedIn ||
        session.identityRevision != revision) {
      throw ProfileException(
        'Account changed or signed out. Please sign in again.',
      );
    }
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
    };
  }

  Map<String, dynamic> _decode(String raw) {
    if (raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }
}

class ProfileException implements Exception {
  ProfileException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
