import 'package:flutter/material.dart';

import '../../services/app_session_service.dart';
import '../../services/profile_service.dart';
import '../../theme/gabay_theme.dart';
import '../../widgets/profile/profile_menu_widgets.dart';
import '../../widgets/shared/gabay_page_route.dart';
import '../login_page.dart';
import '../shared/edit_profile_page.dart';
import 'linked_navigator_cane_page.dart';

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
                  icon: Icons.link_rounded,
                  title: 'Linked Navigator Cane',
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

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D4ED8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Change Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _passwordField(
                label: 'Current Password',
                controller: _currentPasswordController,
                isVisible: _showCurrentPassword,
                onVisibilityToggle: () {
                  setState(() => _showCurrentPassword = !_showCurrentPassword);
                },
              ),
              _passwordField(
                label: 'New Password',
                controller: _newPasswordController,
                isVisible: _showNewPassword,
                onVisibilityToggle: () {
                  setState(() => _showNewPassword = !_showNewPassword);
                },
              ),
              _passwordField(
                label: 'Confirm Password',
                controller: _confirmPasswordController,
                isVisible: _showConfirmPassword,
                onVisibilityToggle: () {
                  setState(() => _showConfirmPassword = !_showConfirmPassword);
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_newPasswordController.text !=
                        _confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Passwords do not match'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Password change unavailable. No password was changed.',
                        ),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: g.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Change Password',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required bool isVisible,
    required VoidCallback onVisibilityToggle,
  }) {
    final g = context.gabay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: g.textSecondary,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: !isVisible,
          style: TextStyle(color: g.textPrimary),
          decoration: InputDecoration(
            fillColor: g.chipBackground,
            filled: true,
            suffixIcon: IconButton(
              icon: Icon(
                isVisible ? Icons.visibility : Icons.visibility_off,
                color: g.textSecondary,
                size: 20,
              ),
              onPressed: onVisibilityToggle,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: g.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: g.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: g.accent, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
