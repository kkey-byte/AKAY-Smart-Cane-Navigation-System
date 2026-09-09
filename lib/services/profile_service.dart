import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/patient_profile.dart';
import 'app_session_service.dart';

/// Progressive profile completion: Users + PatientProfiles via `/api/profile`.
class ProfileService {
  ProfileService._();

  static final ProfileService instance = ProfileService._();

  final _client = http.Client();

  Future<ProfileBundle> fetchProfile() async {
    final session = AppSessionService.instance;
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
    final params = <String, String>{
      if (session.userId != null && session.userId!.isNotEmpty)
        'userId': session.userId!,
      if (firebaseUid != null && firebaseUid.isNotEmpty)
        'firebaseUid': firebaseUid,
    };

    if (params.isEmpty) {
      throw ProfileException('No signed-in user to load profile for.');
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/profile').replace(
      queryParameters: params,
    );
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    final body = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProfileException(
        (body['message'] ?? 'Failed to load profile').toString(),
        statusCode: response.statusCode,
      );
    }

    final bundle = ProfileBundle.fromJson(body);
    await session.updateProfileCache(
      name: bundle.name,
      phone: bundle.phone,
      profilePicture: bundle.profilePicture,
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
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;

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

    final uri = Uri.parse('${ApiConfig.baseUrl}/profile');
    final response = await _client
        .put(
          uri,
          headers: const {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload),
        )
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

    final bundle = ProfileBundle.fromJson(body);
    await session.updateProfileCache(
      name: bundle.name,
      phone: bundle.phone,
      profilePicture: bundle.profilePicture,
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
