import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'pages/splash_page.dart';
import 'theme/gabay_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _ensureFirebase();
  runApp(const MyApp());
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
          debugShowCheckedModeBanner: false,
          title: 'GABAY',
          themeMode: ThemeController.instance.themeMode,
          theme: GabayTheme.lightTheme,
          darkTheme: GabayTheme.darkTheme,
          home: const SplashPage(),
        );
      },
    );
  }
}
