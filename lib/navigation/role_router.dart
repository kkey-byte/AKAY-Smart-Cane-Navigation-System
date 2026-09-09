import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../pages/caregiver/caregiver_dashboard.dart';
import '../pages/visually_impaired/visually_impaired_dashboard.dart';
import '../widgets/shared/gabay_page_route.dart';

/// Shared role → dashboard navigation used by signup and login.
class RoleRouter {
  RoleRouter._();

  /// Maps a PostgreSQL `Users.role` string to its dashboard widget.
  ///
  /// Returns `null` when [role] is missing or unrecognized.
  static Widget? dashboardForRole(String? role) {
    switch ((role ?? '').toLowerCase().trim().replaceAll(' ', '_')) {
      case 'caregiver':
        return const CaregiverDashboard();
      case 'visually_impaired':
      case 'navigator':
      case 'vi':
        return const VisuallyImpairedDashboard();
      default:
        final parsed = UserRole.fromBackend(role);
        return switch (parsed) {
          UserRole.caregiver => const CaregiverDashboard(),
          UserRole.navigator => const VisuallyImpairedDashboard(),
          null => null,
        };
    }
  }

  /// Routes to the correct dashboard and clears the entire auth stack
  /// so the user cannot press Back into signup/login.
  ///
  /// Returns `true` when navigation succeeded.
  static bool routeBasedOnRole(String? role, BuildContext context) {
    final destination = dashboardForRole(role);
    if (destination == null || !context.mounted) {
      return false;
    }

    Navigator.of(context).pushAndRemoveUntil(
      GabayPageRoute(page: destination),
      (_) => false,
    );
    return true;
  }

  /// Convenience overload when the app already has a [UserRole].
  static bool routeBasedOnUserRole(UserRole role, BuildContext context) {
    return routeBasedOnRole(role.backendValue, context);
  }
}
