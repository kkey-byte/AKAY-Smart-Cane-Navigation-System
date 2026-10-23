import 'dart:convert';

import 'package:flutter/material.dart';

import '../../pages/shared/about_page.dart';
import '../../pages/shared/privacy_policy_page.dart';
import '../../pages/shared/terms_conditions_page.dart';
import '../../theme/gabay_theme.dart';
import '../../theme/theme_controller.dart';
import '../shared/floating_bottom_nav_shell.dart';
import 'logout_confirmation_dialog.dart';
import 'profile_header_clipper.dart';

class ProfileMenuItem {
  const ProfileMenuItem({
    required this.icon,
    required this.title,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;
}

class GabayProfileScaffold extends StatelessWidget {
  const GabayProfileScaffold({
    super.key,
    required this.name,
    required this.email,
    required this.role,
    required this.sections,
    required this.onLogout,
    this.avatarAsset,
    this.avatarUrl,
    this.bottomPadding = GabayNavMetrics.contentClearance,
  });

  final String name;
  final String email;
  final String role;
  final List<ProfileSectionGroup> sections;
  final VoidCallback onLogout;
  final String? avatarAsset;

  /// Network URL or `data:image/...;base64,...` from Users.profile_picture.
  final String? avatarUrl;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          children: [
            SizedBox(
              height: ProfileHeaderMetrics.headerStackHeight + 88,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  ClipPath(
                    clipper: ProfileHeaderClipper(
                      notchRadius: ProfileHeaderMetrics.notchRadius,
                      sideDrop: ProfileHeaderMetrics.sideDrop,
                    ),
                    child: Container(
                      height: ProfileHeaderMetrics.clipHeight,
                      width: double.infinity,
                      color: ProfileHeaderMetrics.navyBlue,
                      child: SafeArea(
                        bottom: false,
                        child: _ProfileHeaderBar(
                          onBack: Navigator.canPop(context)
                              ? () => Navigator.pop(context)
                              : null,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: ProfileHeaderMetrics.avatarTop,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _ProfileAvatar(
                        asset: avatarAsset,
                        imageUrl: avatarUrl,
                      ),
                    ),
                  ),
                  Positioned(
                    top: ProfileHeaderMetrics.headerStackHeight + 12,
                    left: 24,
                    right: 24,
                    child: Column(
                      children: [
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: g.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: g.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          role,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: g.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ...sections.map(
              (section) => ProfileSectionCard(
                title: section.title,
                items: section.items,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _LogoutCard(
                onTap: () =>
                    showLogoutConfirmationDialog(context, onConfirm: onLogout),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderBar extends StatelessWidget {
  const _ProfileHeaderBar({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: onBack == null
                ? null
                : IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: onBack,
                    tooltip: 'Back',
                  ),
          ),
          const Expanded(
            child: Text(
              'Profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 48, height: 48),
        ],
      ),
    );
  }
}

class ProfileSectionGroup {
  const ProfileSectionGroup({required this.title, required this.items});

  final String title;
  final List<ProfileMenuItem> items;
}

class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<ProfileMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: g.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: g.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: g.border.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: g.shadow,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 52,
                      endIndent: 16,
                      color: g.border.withValues(alpha: 0.5),
                    ),
                  ProfileMenuRow(item: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileMenuRow extends StatelessWidget {
  const ProfileMenuRow({super.key, required this.item});

  final ProfileMenuItem item;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(item.icon, color: g.textPrimary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 16,
                    color: g.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              item.trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: g.textSecondary,
                    size: 20,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileDarkModeToggle extends StatelessWidget {
  const ProfileDarkModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return Transform.scale(
          scale: 0.85,
          child: Switch(
            value: ThemeController.instance.isDarkMode,
            onChanged: ThemeController.instance.setDarkMode,
            activeTrackColor: g.accent,
          ),
        );
      },
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.asset, this.imageUrl});

  final String? asset;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final fallback = Icon(Icons.person_rounded, size: 52, color: g.accent);

    Widget child = fallback;
    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('data:image')) {
        try {
          final comma = url.indexOf(',');
          final raw = comma >= 0 ? url.substring(comma + 1) : url;
          child = Image.memory(
            base64Decode(raw),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
        } catch (_) {
          child = fallback;
        }
      } else if (url.startsWith('https://')) {
        child = Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        );
      }
    } else if (asset != null && asset!.isNotEmpty) {
      child = Image.asset(
        asset!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    return Container(
      width: ProfileHeaderMetrics.avatarSize,
      height: ProfileHeaderMetrics.avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: ProfileHeaderMetrics.avatarBorderWidth,
        ),
        color: g.accentTint,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Container(
      decoration: BoxDecoration(
        color: g.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: g.border.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: g.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.logout_rounded, color: g.danger, size: 22),
                const SizedBox(width: 12),
                Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: g.danger,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<ProfileMenuItem> profileOthersSection(BuildContext context) {
  return [
    ProfileMenuItem(
      icon: Icons.description_outlined,
      title: 'Terms & Conditions',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TermsConditionsPage()),
        );
      },
    ),
    ProfileMenuItem(
      icon: Icons.privacy_tip_outlined,
      title: 'Privacy Policy',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
        );
      },
    ),
    ProfileMenuItem(
      icon: Icons.dark_mode_outlined,
      title: 'Dark mode',
      trailing: const ProfileDarkModeToggle(),
      onTap: ThemeController.instance.toggle,
    ),
    ProfileMenuItem(
      icon: Icons.info_outline,
      title: 'About',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutPage()),
        );
      },
    ),
  ];
}
