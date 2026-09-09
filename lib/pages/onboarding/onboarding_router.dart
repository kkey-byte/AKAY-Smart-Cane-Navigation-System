import 'package:flutter/material.dart';

import '../../models/user_role.dart';
import '../../services/app_session_service.dart';
import '../../widgets/shared/gabay_page_route.dart';
import '../caregiver/caregiver_dashboard.dart';
import '../visually_impaired/visually_impaired_dashboard.dart';
import 'caregiver_onboarding_page.dart';
import 'navigator_onboarding_page.dart';

class OnboardingRouter extends StatelessWidget {
  const OnboardingRouter({super.key});

  static Future<void> openDashboard(BuildContext context) async {
    await AppSessionService.instance.completeOnboarding();
    if (!context.mounted) return;

    final role = AppSessionService.instance.role;
    final destination = role == UserRole.navigator
        ? const VisuallyImpairedDashboard()
        : const CaregiverDashboard();

    Navigator.of(context).pushAndRemoveUntil(
      GabayPageRoute(page: destination),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = AppSessionService.instance.role;

    if (role == UserRole.navigator) {
      return const NavigatorOnboardingPage();
    }

    return const CaregiverOnboardingPage();
  }
}
