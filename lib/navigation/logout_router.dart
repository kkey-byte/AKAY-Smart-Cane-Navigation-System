import 'dart:async';
import 'package:flutter/material.dart';
import '../pages/login_page.dart';
import '../services/app_session_service.dart';
import '../widgets/shared/gabay_page_route.dart';

/// Capture the app navigator before session listeners can rebuild the profile.
/// The signed-out screen never waits for network or tracking cleanup.
class LogoutRouter {
  LogoutRouter._();

  static Future<void> logout(
    BuildContext context, {
    Future<void> Function()? logout,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final completion = Future<void>.sync(
      logout ?? AppSessionService.instance.logout,
    );
    unawaited(
      navigator.pushAndRemoveUntil<void>(
        GabayPageRoute(page: const LoginPage()),
        (_) => false,
      ),
    );
    try {
      await completion;
    } catch (_) {
      if (navigator.mounted && messenger?.mounted == true) {
        messenger!.showSnackBar(
          const SnackBar(
            content: Text(
              'Your local session was cleared, but sign-out could not be confirmed. Please try again.',
            ),
          ),
        );
      }
    }
  }
}
