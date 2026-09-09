import 'package:flutter/material.dart';

import '../../models/navigator_health_profile.dart';
import '../../services/app_session_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/profile/profile_menu_widgets.dart';
import '../../widgets/shared/gabay_page_route.dart';
import '../caregiver/caregiver_profile.dart';
import '../login_page.dart';
import '../shared/edit_profile_page.dart';
import '../shared/information_health_status_page.dart';
import 'vi_caregivers_page.dart';

class VisuallyImpairedProfilePage extends StatefulWidget {
  const VisuallyImpairedProfilePage({super.key});

  @override
  State<VisuallyImpairedProfilePage> createState() =>
      _VisuallyImpairedProfilePageState();
}

class _VisuallyImpairedProfilePageState
    extends State<VisuallyImpairedProfilePage> {
  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    try {
      await ProfileService.instance.fetchProfile();
    } catch (_) {
      // Keep cached session values if offline.
    }
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
    if (!mounted) return;
    await _refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSessionService.instance,
      builder: (context, _) {
        final session = AppSessionService.instance;
        final name = (session.displayName?.trim().isNotEmpty == true)
            ? session.displayName!
            : 'Navigator';
        final email = session.email ?? 'Not signed in';
        final picture = session.profilePicture;

        return GabayProfileScaffold(
          name: name,
          email: email,
          role: 'Navigator',
          avatarUrl: picture,
          avatarAsset: (picture == null || picture.isEmpty)
              ? 'assets/profile.jpg'
              : null,
          sections: [
            ProfileSectionGroup(
              title: 'Your Account',
              items: [
                ProfileMenuItem(
                  icon: Icons.edit_outlined,
                  title: 'Edit Profile',
                  onTap: _openEditProfile,
                ),
                ProfileMenuItem(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordPage(),
                      ),
                    );
                  },
                ),
                ProfileMenuItem(
                  icon: Icons.monitor_heart_outlined,
                  title: 'Information & Health Status',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InformationHealthStatusPage(
                          profile: NavigatorHealthProfile.navigatorUser,
                        ),
                      ),
                    );
                  },
                ),
                ProfileMenuItem(
                  icon: Icons.link_rounded,
                  title: 'Caregivers',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ViCaregiversPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
            ProfileSectionGroup(
              title: 'Others',
              items: profileOthersSection(context),
            ),
          ],
          onLogout: () async {
            await AppSessionService.instance.logout();
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              GabayPageRoute(page: const LoginPage()),
              (_) => false,
            );
          },
        );
      },
    );
  }
}
