import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import '../models/dashboard_snapshot.dart';
import '../models/user_role.dart';
import 'app_session_service.dart';
import 'secure_api.dart';

class DashboardService {
  DashboardService({SecureApi? api}) : api = api ?? SecureApi.instance;
  static final instance = DashboardService();
  final SecureApi api;
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
  Stream<DashboardSnapshot> watch(String uid) => api
      .watchGet('/v2/navigators/${Uri.encodeComponent(uid)}/dashboard')
      .map(DashboardSnapshot.fromJson);
  Future<void> presence(bool active) async {
    await api.request('POST', '/v2/dashboard/presence', {'active': active});
  }
}

/// Dashboard activity heartbeat; never starts/stops GPS or changes navigation.
class DashboardPresenceReporter with WidgetsBindingObserver {
  DashboardPresenceReporter(this.service);
  final DashboardService service;
  Timer? _timer;
  bool _sending = false;
  bool _foreground = true;
  bool _disposed = false;
  bool _pending = false;
  String? _owner;
  void start() {
    _owner = service.currentUid;
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    AppSessionService.instance.addListener(_send);
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _send());
    _send();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _send();
  }

  void _send() {
    if (_disposed ||
        service.currentUid == null ||
        service.currentUid != _owner) {
      return;
    }
    if (_sending) {
      _pending = true;
      return;
    }
    _pending = false;
    final session = AppSessionService.instance;
    _sending = true;
    unawaited(
      service
          .presence(
            _foreground &&
                session.isLoggedIn &&
                session.role == UserRole.navigator,
          )
          .catchError((Object _) {})
          .whenComplete(() {
            _sending = false;
            if (_pending) _send();
          }),
    );
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AppSessionService.instance.removeListener(_send);
    if (service.currentUid == _owner) {
      unawaited(service.presence(false).catchError((Object _) {}));
    }
  }
}
