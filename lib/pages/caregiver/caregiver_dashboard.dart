import 'package:flutter/material.dart';

import '../../models/gabay_notification.dart';
import '../../services/app_session_service.dart';
import '../../services/notification_service.dart';
import '../../services/profile_service.dart';
import '../../theme/gabay_theme.dart';
import '../../widgets/shared/dashboard_pairing_card.dart';
import '../../widgets/dashboard_widgets/dashboard_header.dart';
import '../../widgets/dashboard_widgets/dashboard_live_section.dart';
import '../../widgets/dashboard_widgets/recorded_reports.dart';
import '../../widgets/dashboard_widgets/activity_card.dart';
import '../../widgets/dashboard_widgets/bottom_nav.dart';
import '../../widgets/shared/floating_bottom_nav_shell.dart';
import '../../widgets/shared/gabay_page_route.dart';
import '../../widgets/shared/gabay_tab_body.dart';
import 'caregiver_track.dart';
import 'caregiver_reports.dart';
import 'caregiver_profile.dart';
import 'notifications_page.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  int _selectedIndex = 0;
  bool _profileLoading = true;
  bool _profileError = false;
  final _notificationService = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    _notificationService.addListener(_onNotificationsChanged);
    // Pull Users.name so the header shows a formal display name.
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    if (mounted) {
      setState(() {
        _profileLoading = true;
        _profileError = false;
      });
    }
    try {
      await ProfileService.instance.fetchProfile();
    } catch (_) {
      if (mounted) setState(() => _profileError = true);
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  void _onNotificationsChanged() => setState(() {});

  void _onNavTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  void _openNotifications() {
    context.pushGabayPage(
      NotificationsPage(onNavigate: _handleNotificationNavigation),
    );
  }

  void _handleNotificationNavigation(NotificationDestination destination) {
    Navigator.pop(context);

    switch (destination) {
      case NotificationDestination.emergency:
      case NotificationDestination.track:
        _onNavTapped(1);
      case NotificationDestination.reports:
        _onNavTapped(2);
      case NotificationDestination.profile:
        _onNavTapped(3);
      case NotificationDestination.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GabayTabBody(
        index: _selectedIndex,
        children: [
          _buildDashboardPage(context),
          const TrackPage(),
          const ReportsPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: FloatingBottomNavShell(
        child: BottomNav(
          currentIndex: _selectedIndex,
          onIndexChanged: _onNavTapped,
        ),
      ),
    );
  }

  /// Formal display name from Users.name (session cache / profile API).
  String get _displayName {
    final name = AppSessionService.instance.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Caregiver';
  }

  Widget _buildDashboardPage(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          GabayNavMetrics.contentClearance,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListenableBuilder(
              listenable: AppSessionService.instance,
              builder: (context, _) {
                final name = _displayName;
                return Semantics(
                  label: 'Caregiver: $name',
                  child: DashboardHeader(
                    greeting: 'Hello, Welcome back!',
                    name: name,
                    unreadCount: _notificationService.unreadCount,
                    onNotificationTap: _openNotifications,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            DashboardLiveSection(
              caregiver: true,
              onViewMap: () => _onNavTapped(1),
            ),
            const SizedBox(height: 20),
            const DashboardPairingCard(caregiver: true),
            const SizedBox(height: 16),
            if (_profileLoading)
              const LinearProgressIndicator(semanticsLabel: 'Loading profile'),
            if (_profileError)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Profile refresh failed. Cached details may be out of date.',
                  ),
                  TextButton(
                    onPressed: _loadDisplayName,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            const RecordedReports(caregiver: true, compact: true),
            const SizedBox(height: 16),
            Text('Recent Activity', style: GabayTheme.sectionTitle(context)),
            const SizedBox(height: 14),
            const RecentActivityList(),
          ],
        ),
      ),
    );
  }
}
