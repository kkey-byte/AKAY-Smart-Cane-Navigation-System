import '../theme/gabay_typography.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/gabay_theme.dart';
import '../theme/gabay_visual_tokens.dart';
import 'login_page.dart';
import 'signup_page.dart';
import '../widgets/gabay_logo.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  static const _durationMs = 4600;
  late final AnimationController _controller;
  late final Animation<double> _logo, _name, _liquid, _tagline, _login, _start;
  Animation<double> _phase(
    int start,
    int end, {
    Curve curve = Curves.easeOutCubic,
  }) => _controller.drive(
    CurveTween(
      curve: Interval(start / _durationMs, end / _durationMs, curve: curve),
    ),
  );
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _durationMs),
    );
    _logo = _phase(160, 900);
    _name = _phase(1000, 1600);
    _liquid = _phase(1700, 2700, curve: Curves.linear);
    _tagline = _phase(2850, 3350);
    _login = _phase(3450, 4050);
    _start = _phase(3800, 4600);
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _reveal(
    Animation<double> progress, {
    required Widget child,
    double rise = 0,
    bool scaleLogo = false,
  }) => AnimatedBuilder(
    animation: progress,
    child: child,
    builder: (context, child) {
      final value = progress.value;
      // Suppress incoming Hero flights until this element's entrance finishes.
      return HeroMode(
        enabled: value == 1,
        child: IgnorePointer(
          ignoring: value < 1,
          child: ExcludeSemantics(
            excluding: value < 1,
            child: Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, rise * (1 - value)),
                child: Transform.scale(
                  scale: scaleLogo ? .85 + .15 * value : 1,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

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
        : const Color(0xFFF4F8FF);

    return Scaffold(
      backgroundColor: scaffoldBg,

      body: SingleChildScrollView(
        child: SizedBox(
          height: size.height,
          child: Stack(
            children: [
              CustomPaint(size: size, painter: const _LandingBluePainter()),
              ClipPath(
                clipper: _LandingWaveClipper(_liquid),
                child: Container(
                  width: double.infinity,
                  height: size.height,
                  color: scaffoldBg,
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    SizedBox(height: size.height * .15),

                    _reveal(
                      _logo,
                      scaleLogo: true,
                      child: Hero(
                        tag: 'gabay_logo',
                        child: SizedBox(
                          width: 200,
                          height: 140,
                          child: OverflowBox(
                            minHeight: 200,
                            maxHeight: 200,
                            child: GabayLogo(
                              size: 200,
                              color: Color(0xFF008DE0),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    _reveal(
                      _name,
                      rise: 12,
                      child: const Hero(
                        tag: 'gabay_title',
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            "AKAY",
                            style: TextStyle(
                              color: GabayVisualTokens.ink,
                              fontSize: GabayTypography.brand,
                              fontWeight: GabayTypography.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    _reveal(
                      _tagline,
                      rise: 10,
                      child: Hero(
                        tag: 'gabay_subtitle',
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            "Independence Starts Here",
                            style: TextStyle(
                              color: GabayVisualTokens.mutedInk,
                              fontSize: GabayTypography.supporting,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          _reveal(
                            _login,
                            rise: 40,
                            child: SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  gradient: GabayTheme.actionGradient,
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
                                      fontSize: GabayTypography.cardBody,
                                      fontWeight: GabayTypography.medium,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          _reveal(
                            _start,
                            rise: 40,
                            child: SizedBox(
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
                                    fontSize: GabayTypography.cardBody,
                                    fontWeight: GabayTypography.medium,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: size.height * .07),
                        ],
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

// Use the original gradient's bounds so its final colors are unchanged.
class _LandingBluePainter extends CustomPainter {
  const _LandingBluePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final shader = GabayVisualTokens.pageGradient.createShader(
      Offset.zero & size,
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_LandingBluePainter oldDelegate) => false;
}

class _LandingWaveClipper extends CustomClipper<Path> {
  _LandingWaveClipper(this.progress) : super(reclip: progress);
  final Animation<double> progress;
  @override
  Path getClip(Size size) {
    final t = progress.value;
    final settled = Curves.easeOutCubic.transform(t);
    final waveHeight = size.height * .63;
    final amplitude = t == 0 || t == 1
        ? 0.0
        : math.sin(math.pi * t) * size.height * .018;
    double y(double finalY, double phase) =>
        (size.height + 32) * (1 - settled) +
        finalY * waveHeight * settled +
        amplitude * math.sin(2 * math.pi * t + phase);
    return Path()
      ..moveTo(0, y(.91, 0))
      ..cubicTo(
        size.width * .20,
        y(.92, .6),
        size.width * .27,
        y(1.01, 1.1),
        size.width * .39,
        y(.995, 1.6),
      )
      ..cubicTo(
        size.width * .53,
        y(.985, 2.1),
        size.width * .55,
        y(.955, 2.5),
        size.width * .70,
        y(.96, 3),
      )
      ..cubicTo(
        size.width * .90,
        y(.965, 3.5),
        size.width * .94,
        y(.95, 4),
        size.width,
        y(.855, 4.5),
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_LandingWaveClipper oldClipper) =>
      oldClipper.progress != progress;
}
