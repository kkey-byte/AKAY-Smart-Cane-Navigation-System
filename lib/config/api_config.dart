import 'package:flutter/foundation.dart';

/// Resolves the auth API base URL for the external `app_mobile_backend`.
///
/// Override with:
/// `--dart-define=API_BASE_URL=http://192.168.1.10:5000/api`
class ApiConfig {
  ApiConfig._();

  static const String _fromEnv = String.fromEnvironment('API_BASE_URL');

  /// Auth mode: `api` (Postgres via app_mobile_backend) or `local`.
  static const String authMode = String.fromEnvironment(
    'AUTH_MODE',
    defaultValue: 'api',
  );

  static bool get useApi => authMode.toLowerCase() != 'local';

  static String get baseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    return _defaultHost;
  }

  static String get _defaultHost {
    // Android emulator → host machine. Backend default port is 5000.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api';
    }
    // Windows / iOS simulator / web / desktop
    return 'http://localhost:5000/api';
  }
}
