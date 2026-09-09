import 'package:flutter/material.dart';

/// Modern fade + lift transition for pushed pages (no horizontal swipe).
class GabayPageRoute<T> extends PageRouteBuilder<T> {
  GabayPageRoute({
    required Widget page,
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 340),
  }) : super(
          settings: settings,
          transitionDuration: duration,
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.035),
                  end: Offset.zero,
                ).animate(curved),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
                  child: child,
                ),
              ),
            );
          },
        );
}

extension GabayBuildContextNavigator on BuildContext {
  Future<T?> pushGabayPage<T>(Widget page) {
    return Navigator.of(this).push<T>(GabayPageRoute<T>(page: page));
  }
}
