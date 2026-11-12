import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/user_role.dart';
import 'app_session_service.dart';
import 'notification_service.dart';
import 'secure_api.dart';

/// Push is a delivery hint; the permission-checked server feed is authoritative.
class EmergencyPushService {
  EmergencyPushService._();
  static final instance = EmergencyPushService._();
  VoidCallback? onOpen;
  VoidCallback? onForeground;
  String? _key, _token;
  bool _supported = false, _initialized = false;
  Future<void> _pending = Future.value();
  Timer? _registrationRetry;
  bool get _caregiver =>
      AppSessionService.instance.isLoggedIn &&
      AppSessionService.instance.role == UserRole.caregiver;
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _supported = await FirebaseMessaging.instance.isSupported();
      if (!_supported) return;
      AppSessionService.instance.addListener(_sessionChanged);
      FirebaseMessaging.onMessage.listen((message) {
        if (!_caregiver || !_isNotification(message.data['type'])) return;
        unawaited(
          NotificationService.instance
              .refresh()
              .then((_) {
                if (message.data['type'] == 'cane_alert') {
                  onForeground?.call();
                }
              })
              .catchError((Object _) {}),
        );
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        if (_caregiver && _isNotification(message.data['type'])) onOpen?.call();
      });
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        if (_caregiver) unawaited(_register(token).catchError((Object _) {}));
      });
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (_isNotification(initial?.data['type'])) {
        // The UI callback waits for role routing; never trust a push's navigator identity.
        _openAfterLogin = true;
      }
      _sessionChanged();
    } catch (_) {
      /* Unsupported devices still use the persisted in-app feed. */
    }
  }

  bool _openAfterLogin = false;
  bool _isNotification(Object? type) =>
      type == 'cane_alert' || type == 'destination_progress';
  void _sessionChanged() {
    final session = AppSessionService.instance;
    final next = _caregiver
        ? '${session.identityRevision}:${session.userId}'
        : null;
    if (next == _key) return;
    final hadIdentity = _key != null;
    _key = next;
    _registrationRetry?.cancel();
    if (next != null) {
      _registrationRetry = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_key == next && _token == null) {
          _pending = _pending
              .then((_) async {
                final settings = await FirebaseMessaging.instance
                    .getNotificationSettings();
                if (_key == next &&
                    settings.authorizationStatus ==
                        AuthorizationStatus.authorized) {
                  await _bind();
                }
              })
              .catchError((Object _) {});
        }
      });
    }
    // Serialize token deletion/registration across rapid logout and login.
    _pending = _pending
        .then((_) async {
          if (hadIdentity) {
            try {
              await FirebaseMessaging.instance.deleteToken();
            } catch (_) {}
            _token = null;
          }
          if (next != _key || next == null) return;
          final settings = await FirebaseMessaging.instance
              .getNotificationSettings();
          if (settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional) {
            await _bind();
          }
          if (_openAfterLogin && _caregiver) {
            _openAfterLogin = false;
            onOpen?.call();
          }
        })
        .catchError((Object _) {});
  }

  /// Invoked by the existing notification-actions menu (browser user gesture).
  Future<void> enable() async {
    if (!_supported || !_caregiver) {
      throw StateError('Push notifications are unavailable on this device.');
    }
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      throw StateError(
        'Notifications are blocked. Allow them in device or browser settings.',
      );
    }
    await _pending;
    await _bind();
  }

  Future<void> _bind() async {
    final key = _key;
    const vapid = String.fromEnvironment('FCM_WEB_VAPID_KEY');
    if (kIsWeb && vapid.isEmpty) {
      throw StateError(
        'Web push requires the project VAPID key configuration.',
      );
    }
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: kIsWeb ? vapid : null,
    );
    if (key == _key && _caregiver && token != null) await _register(token);
  }

  Future<void> _register(String token) async {
    if (!_caregiver) return;
    final key = _key;
    await SecureApi.instance.request('PUT', '/v2/push-token', {'token': token});
    if (key == _key) _token = token;
  }

  Future<void> unregister() async {
    final token = _token;
    if (token == null) return;
    try {
      await SecureApi.instance.request('DELETE', '/v2/push-token', {
        'token': token,
      });
    } catch (_) {}
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _token = null;
  }
}
