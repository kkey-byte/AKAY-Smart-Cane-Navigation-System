import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/patient_health_status.dart';
import 'app_session_service.dart';
import 'profile_service.dart';
import 'secure_api.dart';

class HealthStatusService {
  HealthStatusService({
    http.Client? client,
    this.baseUrl,
    Future<String?> Function()? idToken,
  }) : _client = client ?? http.Client(),
       _idToken =
           idToken ??
           (() =>
               FirebaseAuth.instance.currentUser?.getIdToken() ??
               Future.value());
  static final instance = HealthStatusService();
  final http.Client _client;
  final String? baseUrl;
  final Future<String?> Function() _idToken;

  Future<PatientHealthStatus?> fetch() => _request();
  Future<PatientHealthStatus> save(PatientHealthStatus status) async {
    final result = await _request(status);
    if (result == null ||
        jsonEncode(result.toJson()) != jsonEncode(status.toJson())) {
      throw ProfileException(
        'The server did not confirm the saved health fields. Reload and try again.',
      );
    }
    return result;
  }

  Future<PatientHealthStatus?> _request([PatientHealthStatus? value]) async {
    final session = AppSessionService.instance;
    final revision = session.identityRevision;
    if (!session.isLoggedIn) throw ProfileException('Please sign in again.');
    final token = await _idToken();
    void checkIdentity() {
      if (!session.isLoggedIn || session.identityRevision != revision) {
        throw ProfileException(
          'Account changed. Reopen your health information.',
        );
      }
    }

    checkIdentity();
    if (token == null || token.isEmpty) {
      throw ProfileException('Please sign in again.');
    }
    final uri = Uri.parse(
      '${baseUrl ?? SecureApi.preferredBase ?? ApiConfig.baseUrl}/health-status',
    );
    if (uri.scheme != 'https' &&
        uri.host != '127.0.0.1' &&
        uri.host != 'localhost' &&
        uri.host != '10.0.2.2') {
      throw ProfileException('A secure health service connection is required.');
    }
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final response =
        await (value == null
                ? _client.get(uri, headers: headers)
                : _client.put(
                    uri,
                    headers: headers,
                    body: jsonEncode(value.toJson()),
                  ))
            .timeout(const Duration(seconds: 20));
    checkIdentity();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProfileException(
        response.statusCode == 409
            ? 'Save your patient profile before adding health status.'
            : 'Health status service unavailable. Your changes have not been saved.',
        statusCode: response.statusCode,
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map || !body.containsKey('health_status')) {
      throw ProfileException('Invalid health status response.');
    }
    final row = body['health_status'];
    return row == null
        ? null
        : PatientHealthStatus.fromJson(Map<String, dynamic>.from(row as Map));
  }
}
