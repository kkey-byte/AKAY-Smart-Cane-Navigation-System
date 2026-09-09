import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../services/app_session_service.dart';
import '../theme/gabay_theme.dart';
import '../widgets/gabay_logo.dart';
import '../widgets/shared/gabay_page_route.dart';
import 'caregiver/caregiver_dashboard.dart';
import 'landing_page.dart';
import 'onboarding/onboarding_router.dart';
import 'visually_impaired/visually_impaired_dashboard.dart';

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
    Widget destination;

    if (session.isLoggedIn) {
      if (!session.onboardingComplete) {
        destination = const OnboardingRouter();
      } else if (session.role == UserRole.navigator) {
        destination = const VisuallyImpairedDashboard();
      } else {
        destination = const CaregiverDashboard();
      }
    } else {
      destination = const LandingPage();
    }

    Navigator.pushReplacement(
      context,
      GabayPageRoute(page: destination),
    );
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
            colors: [
              Color(0xFF0F52BA),
              Color(0xFF03163A),
            ],
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
                    child: GabayLogo(
                      size: 150,
                      color: g.accent,
                    ),
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
