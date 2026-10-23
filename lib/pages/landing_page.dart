import 'package:flutter/material.dart';
import '../theme/gabay_theme.dart';
import 'login_page.dart';
import 'signup_page.dart';
import '../widgets/gabay_logo.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final viewport = MediaQuery.of(context).size;
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final size = Size(
      viewport.width,
      viewport.height.clamp(
        720.0 + (scale - 1).clamp(0, 3) * 180,
        double.infinity,
      ),
    );
    final scaffoldBg = Theme.of(context).brightness == Brightness.dark
        ? g.scaffoldBackground
        : const Color(0xFFF3F3F3);

    return Scaffold(
      backgroundColor: scaffoldBg,

      body: SingleChildScrollView(
        child: SizedBox(
          height: size.height,
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                color: scaffoldBg,
              ),

              ClipPath(
                clipper: _LandingWaveClipper(),
                child: Container(
                  width: double.infinity,
                  height: size.height * .63,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFF10428D), Color(0xFF021E45)],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    SizedBox(height: size.height * .15),

                    Hero(
                      tag: 'gabay_logo',
                      child: GabayLogo(size: 200, color: Color(0xFF008DE0)),
                    ),

                    const SizedBox(height: 10),

                    const Hero(
                      tag: 'gabay_title',
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          "AKAY",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Hero(
                      tag: 'gabay_subtitle',
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          "Independence Starts Here",
                          style: TextStyle(
                            color: Color(0xFF667F9F),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,

                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 40 * (1 - value)),
                            child: child,
                          ),
                        );
                      },

                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                    colors: [
                                      Color(0xFF008FE5),
                                      Color(0xFF004878),
                                    ],
                                  ),
                                ),
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder:
                                            (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                            ) => const LoginPage(),
                                        transitionsBuilder:
                                            (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                              child,
                                            ) {
                                              return SlideTransition(
                                                position:
                                                    Tween<Offset>(
                                                      begin: const Offset(0, 1),
                                                      end: Offset.zero,
                                                    ).animate(
                                                      CurvedAnimation(
                                                        parent: animation,
                                                        curve:
                                                            Curves.easeOutCubic,
                                                      ),
                                                    ),
                                                child: child,
                                              );
                                            },
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: const Text(
                                    "Login",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                          ) => const SignupPage(),
                                      transitionsBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                            child,
                                          ) {
                                            return SlideTransition(
                                              position:
                                                  Tween<Offset>(
                                                    begin: const Offset(0, 1),
                                                    end: Offset.zero,
                                                  ).animate(
                                                    CurvedAnimation(
                                                      parent: animation,
                                                      curve:
                                                          Curves.easeOutCubic,
                                                    ),
                                                  ),
                                              child: child,
                                            );
                                          },
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: g.surface,
                                  foregroundColor: g.heading,
                                  side: BorderSide(color: g.heading, width: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text(
                                  "Get Started",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: size.height * .07),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(0, size.height * .91)
    ..cubicTo(
      size.width * .20,
      size.height * .92,
      size.width * .27,
      size.height * 1.01,
      size.width * .39,
      size.height * .995,
    )
    ..cubicTo(
      size.width * .53,
      size.height * .985,
      size.width * .55,
      size.height * .955,
      size.width * .70,
      size.height * .96,
    )
    ..cubicTo(
      size.width * .90,
      size.height * .965,
      size.width * .94,
      size.height * .95,
      size.width,
      size.height * .855,
    )
    ..lineTo(size.width, 0)
    ..close();

  @override
  bool shouldReclip(_LandingWaveClipper oldClipper) => false;
}
