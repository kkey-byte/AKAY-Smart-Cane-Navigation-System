import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'pages/splash_page.dart';
import 'theme/gabay_theme.dart';
import 'theme/theme_controller.dart';
import 'services/breadcrumb_service.dart';
import 'services/notification_service.dart';
import 'services/emergency_push_service.dart';
import 'services/app_session_service.dart';
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
  await _ensureFirebase();
  await BreadcrumbService.instance.initialize();
  NotificationService.instance.initialize();
  EmergencyPushService.instance.onOpen = _openEmergencyNotifications;
  EmergencyPushService.instance.onForeground = () =>
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: const Text(
            'A cane alert was received. Check Notifications.',
          ),
          action: SnackBarAction(
            label: 'View',
            onPressed: _openEmergencyNotifications,
          ),
        ),
      );
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
