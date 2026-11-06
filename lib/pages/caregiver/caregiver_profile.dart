import 'package:flutter/material.dart';

import '../../services/app_session_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/profile/profile_menu_widgets.dart';
import '../../widgets/shared/gabay_page_route.dart';
import '../login_page.dart';
import '../shared/change_password_page.dart';
import '../shared/edit_profile_page.dart';
import 'navigator_health_details_page.dart';
import 'linked_navigator_cane_page.dart';

export '../shared/change_password_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loadingProfile = true;
  bool _profileError = false;

  @override
  void initState() {
    super.initState();
    // Refresh Users.profile_picture so the header avatar stays current.
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
            : 'Caregiver';
        final email = session.email ?? 'Not signed in';
        final picture = session.profilePicture;

        return GabayProfileScaffold(
          name: name,
          email: email,
          role: 'Caregiver',
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
                  icon: Icons.person_outline,
                  title: 'Profile',
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
                  icon: Icons.link_rounded,
                  title: 'Linked Navigator',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LinkedNavigatorCanePage(),
                      ),
                    );
                  },
                ),
              ],
            ),
            ProfileSectionGroup(
              title: 'Others',
              items: [
                ProfileMenuItem(
                  icon: Icons.monitor_heart_outlined,
                  title: 'Navigator Health Details',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NavigatorHealthDetailsPage(),
                    ),
                  ),
                ),
                ...profileOthersSection(context),
              ],
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
