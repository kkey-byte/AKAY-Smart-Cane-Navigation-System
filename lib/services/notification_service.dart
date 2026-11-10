import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/gabay_notification.dart';
import '../models/cane_incident.dart';
import '../models/user_role.dart';
import 'app_session_service.dart';
import 'secure_api.dart';

class NotificationService extends ChangeNotifier {
  NotificationService._() : api = SecureApi.instance;
  @visibleForTesting
  NotificationService.forTest(this.api);
  static final NotificationService instance = NotificationService._();
  final SecureApi api;
  final List<GabayNotification> _notifications = [];
  StreamSubscription<Map<String, dynamic>>? _subscription;
  bool _initialized = false;
  int _generation = 0;
  String? _sessionKey;
  String? errorMessage;
  List<GabayNotification> get notifications =>
      List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isEmpty => _notifications.isEmpty;
  List<GabayNotification> grouped(NotificationDateGroup group) =>
      _notifications.where((n) => n.dateGroup == group).toList();
  void initialize() {
    if (_initialized) return;
    _initialized = true;
    AppSessionService.instance.addListener(_sessionChanged);
    _sessionChanged();
  }

  void _sessionChanged() {
    final session = AppSessionService.instance;
    final key = session.isLoggedIn && session.role == UserRole.caregiver
        ? '${session.identityRevision}:${session.userId}'
        : null;
    if (key == _sessionKey) return;
    _sessionKey = key;
    reset();
    if (key == null) return;
    final generation = _generation;
    _subscription = api
        .watchGet('/v2/alerts', interval: const Duration(seconds: 3))
        .listen(
          (data) {
            if (generation != _generation) return;
            try {
              _apply(data);
            } catch (_) {
              _unavailable();
            }
          },
          onError: (Object error) {
            if (generation != _generation) return;
            _unavailable();
          },
        );
  }

  void _unavailable() {
    _notifications.removeWhere((n) => n.incident != null);
    errorMessage =
        'Emergency alerts unavailable. Check your connection and retry.';
    notifyListeners();
  }

  void _apply(Map<String, dynamic> data) {
    final incidents = (data['alerts'] as List)
        .map(
          (row) => CaneIncident.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
    _notifications.removeWhere((n) => n.incident != null);
    _notifications.insertAll(
      0,
      incidents.map(
        (incident) => GabayNotification(
          id: incident.id,
          category: NotificationCategory.emergency,
          title: incident.title,
          description:
              '${incident.status} · ${incident.kind == 'sos' ? 'Assistance requested from cane.' : 'Cane detected unusual movement. Please check on this navigator.'}',
          createdAt: incident.createdAt,
          isRead: incident.isRead,
          destination: NotificationDestination.emergency,
          incident: incident,
        ),
      ),
    );
    errorMessage = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    final generation = _generation;
    try {
      final data = await api.request('GET', '/v2/alerts');
      if (generation == _generation) _apply(data);
    } catch (_) {
      if (generation == _generation) _unavailable();
      rethrow;
    }
  }

  Future<void> respond(String id, String action) async {
    final generation = _generation;
    final result = await api.request(
      'POST',
      '/v2/alerts/${Uri.encodeComponent(id)}/respond',
      {'action': action},
    );
    if (result['accepted'] != true) {
      throw const SecureApiException('Alert response was not confirmed.');
    }
    if (generation == _generation) await refresh();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index < 0 || _notifications[index].isRead) return;
    if (_notifications[index].incident != null) {
      unawaited(_quietResponse(id, 'read'));
      return;
    }
    _notifications[index] = _notifications[index].copyWith(isRead: true);
    notifyListeners();
  }

  Future<void> _quietResponse(String id, String action) async {
    final generation = _generation;
    try {
      await respond(id, action);
    } catch (_) {
      if (generation == _generation) {
        errorMessage = 'Alert update not confirmed. Please retry.';
        notifyListeners();
      }
    }
  }

  void markAllAsRead() {
    for (final n in List.of(_notifications)) {
      markAsRead(n.id);
    }
  }

  void clearAll() {
    for (final n in List.of(_notifications)) {
      delete(n.id);
    }
  }

  void delete(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index < 0) return;
    final incident = _notifications[index].incident;
    if (incident != null) {
      if (!incident.unresolved) unawaited(_quietResponse(id, 'dismiss'));
      return;
    }
    _notifications.removeAt(index);
    notifyListeners();
  }

  /// Identity reset differs from the user clearing resolved notifications.
  void reset() {
    _generation++;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _notifications.clear();
    errorMessage = null;
    notifyListeners();
  }
}
