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

  /// PC Wi-Fi address used by a physical phone on the same network.
  static const String _lanHost = String.fromEnvironment(
    'API_LAN_HOST',
    defaultValue: '10.173.181.41',
  );

  static String get baseUrl => candidateBaseUrls.first;

  /// Android emulator uses 10.0.2.2; a real phone does not.
  /// USB debugging can reach the PC at 127.0.0.1 after `adb reverse tcp:5000 tcp:5000`.
  static List<String> get candidateBaseUrls {
    if (_fromEnv.isNotEmpty) return [_fromEnv];

    if (kIsWeb) return const ['http://localhost:5000/api'];

    if (defaultTargetPlatform == TargetPlatform.android) {
      return [
        'http://127.0.0.1:5000/api',
        'http://$_lanHost:5000/api',
        'http://10.0.2.2:5000/api',
      ];
    }

    return const ['http://localhost:5000/api'];
  }
}
