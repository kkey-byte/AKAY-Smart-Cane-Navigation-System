import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.child,
    this.stepLabel,
    this.progress,
    this.onBack,
    this.bottomBar,
  });

  final Widget child;
  final String? stepLabel;
  final double? progress;
  final VoidCallback? onBack;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Scaffold(
      backgroundColor: g.scaffoldBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      onPressed: onBack,
                      icon: Icon(Icons.arrow_back_rounded, color: g.textPrimary),
                      tooltip: 'Back',
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Column(
                      children: [
                        if (stepLabel != null) ...[
                          Text(
                            stepLabel!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: g.textSecondary,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (progress != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress!.clamp(0, 1),
                              minHeight: 6,
                              backgroundColor: g.chipBackground,
                              color: g.accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: child,
              ),
            ),
            if (bottomBar != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: bottomBar,
              ),
          ],
        ),
      ),
    );
  }
}

class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({
    super.key,
    required this.icon,
    this.size = 120,
    this.colors,
  });

  final IconData icon;
  final double size;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final gradientColors = colors ??
        [
          g.accent,
          const Color(0xFF0057B8),
        ];

    return Container(
      width: size + 48,
      height: size + 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: g.accent.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.46),
    );
  }
}

class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final active = enabled && onPressed != null;

    return Semantics(
      button: true,
      enabled: active,
      label: label,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1EA4FF), Color(0xFF0057B8)],
                  )
                : LinearGradient(
                    colors: [g.border, g.textSecondary.withValues(alpha: 0.5)],
                  ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: g.accent.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: ElevatedButton(
            onPressed: active ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingTextButton extends StatelessWidget {
  const OnboardingTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: context.gabay.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

class OnboardingInfoCard extends StatelessWidget {
  const OnboardingInfoCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
  });

  final String title;
  final String subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: GabayTheme.cardDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: g.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: g.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
