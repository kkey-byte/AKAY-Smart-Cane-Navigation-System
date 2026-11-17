import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'models/cane_incident.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'pages/splash_page.dart';
import 'theme/gabay_theme.dart';
import 'theme/theme_controller.dart';
import 'services/breadcrumb_service.dart';
import 'services/notification_service.dart';
import 'services/emergency_push_service.dart';
import 'services/app_session_service.dart';
import 'services/gabay_tts_service.dart';
import 'models/user_role.dart';
import 'pages/caregiver/notifications_page.dart';
import 'dart:async';

final _navigatorKey = GlobalKey<NavigatorState>();
final _messengerKey = GlobalKey<ScaffoldMessengerState>();
void _openEmergencyNotifications() {
  if (!AppSessionService.instance.isLoggedIn ||
      AppSessionService.instance.role != UserRole.caregiver) {
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
    );
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GabayTtsService.instance.initialize();
  await _ensureFirebase();
  await BreadcrumbService.instance.initialize();
  NotificationService.instance.initialize();
  EmergencyPushService.instance.onOpen = _openEmergencyNotifications;
  runApp(const MyApp());
  unawaited(EmergencyPushService.instance.initialize());
}

/// google-services.json already creates [DEFAULT] on Android, so a second
/// initializeApp() throws and never reaches runApp (black screen).
Future<void> _ensureFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<CaneIncident>? _alerts;
  final Map<String, CaneIncident> _pending = {};
  bool _scheduled = false;
  int _revision = AppSessionService.instance.identityRevision;

  bool get _caregiver =>
      AppSessionService.instance.isLoggedIn &&
      AppSessionService.instance.role == UserRole.caregiver;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppSessionService.instance.addListener(_sessionChanged);
    _alerts = NotificationService.instance.emergencyEvents.listen((incident) {
      _pending[incident.id] = incident;
      _scheduleAlerts();
    });
  }

  void _sessionChanged() {
    final revision = AppSessionService.instance.identityRevision;
    if (!_caregiver || revision != _revision) {
      _pending.clear();
      _messengerKey.currentState?.clearSnackBars();
    }
    _revision = revision;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleAlerts();
  }

  void _scheduleAlerts() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !_caregiver) {
        _pending.clear();
        return;
      }
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != null && state != AppLifecycleState.resumed) return;
      final messenger = _messengerKey.currentState;
      if (messenger == null) return;
      final incidents = _pending.values.toList();
      _pending.clear();
      if (incidents.isNotEmpty) {
        // A fresh emergency or resolution must not wait behind an old popup.
        messenger.clearSnackBars();
        messenger.removeCurrentSnackBar();
      }
      for (final incident in incidents) {
        messenger.showSnackBar(
          SnackBar(
            duration: Duration(seconds: incident.unresolved ? 20 : 8),
            backgroundColor: const Color(0xFF991B1B),
            content: Row(
              children: [
                const Icon(Icons.sos_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    incident.unresolved
                        ? '${incident.title}. Open to check and respond.'
                        : '${incident.title}. Possible emergency resolved${incident.resolution == 'false_alarm' ? ' (false alarm)' : ''}.',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              textColor: Colors.white,
              label: 'View',
              onPressed: _openEmergencyNotifications,
            ),
          ),
        );
      }
      if (incidents.isNotEmpty) unawaited(_playAlertSound());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _playAlertSound() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await const MethodChannel(
          'akay/emergency',
        ).invokeMethod<void>('playAlert');
      } else {
        await SystemSound.play(SystemSoundType.alert);
      }
    } on PlatformException {
      // Keep the visible alert available when device audio is unavailable.
    } on MissingPluginException {
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  @override
  void dispose() {
    unawaited(_alerts?.cancel());
    AppSessionService.instance.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          scaffoldMessengerKey: _messengerKey,
          debugShowCheckedModeBanner: false,
          title: 'AKAY',
          themeMode: ThemeController.instance.themeMode,
          theme: GabayTheme.lightTheme,
          darkTheme: GabayTheme.darkTheme,
          home: const SplashPage(),
        );
      },
    );
  }
}
