import 'package:flutter/material.dart';

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
  bool _loadingProfile = true;
  bool _profileError = false;

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    if (mounted) {
      setState(() {
        _loadingProfile = true;
        _profileError = false;
      });
    }
    try {
      await ProfileService.instance.fetchProfile();
    } catch (_) {
      if (mounted) setState(() => _profileError = true);
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
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
          avatarAsset: null,
          sections: [
            if (_loadingProfile || _profileError)
              ProfileSectionGroup(
                title: 'Profile status',
                items: [
                  ProfileMenuItem(
                    icon: _loadingProfile ? Icons.sync : Icons.error_outline,
                    title: _loadingProfile
                        ? 'Loading profile...'
                        : 'Profile refresh failed. Tap to retry.',
                    onTap: _loadingProfile ? null : _refreshProfile,
                  ),
                ],
              ),
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
                        builder: (_) => const InformationHealthStatusPage(),
                      ),
                    );
                  },
                ),
                ProfileMenuItem(
                  icon: Icons.link_rounded,
                  title: 'Caregivers & Smart Canes',
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
