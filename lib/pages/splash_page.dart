import 'dart:async';

import 'package:flutter/material.dart';

import '../navigation/role_router.dart';
import '../services/app_session_service.dart';
import '../theme/gabay_theme.dart';
import '../widgets/gabay_logo.dart';
import '../widgets/shared/gabay_page_route.dart';
import 'landing_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    await AppSessionService.instance.init();
    if (!mounted) return;
    _navigateNext();
  }

  void _navigateNext() {
    final session = AppSessionService.instance;
    // Use the same role routing as login/signup, including older accounts
    // whose saved onboardingComplete flag is false.
    final destination = session.isLoggedIn
        ? RoleRouter.dashboardForRole(session.role?.backendValue) ??
              const LandingPage()
        : const LandingPage();

    Navigator.pushReplacement(context, GabayPageRoute(page: destination));
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Scaffold(
      backgroundColor: const Color(0xFF03163A),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.1),
            radius: 1.2,
            colors: [Color(0xFF0F52BA), Color(0xFF03163A)],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.8 + 0.2 * value,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Hero(
                    tag: 'gabay_logo',
                    child: GabayLogo(size: 150, color: g.accent),
                  ),
                  const SizedBox(height: 24),
                  const Hero(
                    tag: 'gabay_title',
                    child: Material(
                      type: MaterialType.transparency,
                      child: Text(
                        'GABAY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Hero(
                    tag: 'gabay_subtitle',
                    child: Material(
                      type: MaterialType.transparency,
                      child: Text(
                        'Independence Starts Here',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
