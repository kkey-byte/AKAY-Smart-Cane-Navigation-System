import 'package:flutter/material.dart';

import '../navigation/role_router.dart';
import '../services/app_session_service.dart';
import '../widgets/shared/gabay_page_route.dart';
import 'landing_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _sessionReady = false;
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await AppSessionService.instance.init();
    if (!mounted) return;
    _navigateNext();
  }

  void _navigateNext() {
    final session = AppSessionService.instance;
    // Use the same role routing as login/signup, including older accounts
    // whose saved onboardingComplete flag is false.
    final destination = session.isLoggedIn
        ? RoleRouter.dashboardForRole(session.role?.backendValue)
        : null;
    if (destination != null) {
      Navigator.pushReplacement(context, GabayPageRoute(page: destination));
    } else {
      // The welcome is already visible: do not push a second copy or replay it.
      setState(() => _sessionReady = true);
    }
  }

  @override
  Widget build(BuildContext context) => ExcludeFocus(
    excluding: !_sessionReady,
    child: IgnorePointer(ignoring: !_sessionReady, child: const LandingPage()),
  );
}
