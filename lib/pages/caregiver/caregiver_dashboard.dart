import 'package:flutter/material.dart';

import '../../models/gabay_notification.dart';
import '../../services/app_session_service.dart';
import '../../services/notification_service.dart';
import '../../services/profile_service.dart';
import '../../theme/gabay_theme.dart';
import '../../widgets/dashboard_widgets/dashboard_header.dart';
import '../../widgets/dashboard_widgets/live_status_card.dart';
import '../../widgets/dashboard_widgets/stat_card.dart';
import '../../widgets/dashboard_widgets/location_card.dart';
import '../../widgets/dashboard_widgets/activity_card.dart';
import '../../widgets/dashboard_widgets/bottom_nav.dart';
import '../../widgets/shared/floating_bottom_nav_shell.dart';
import '../../widgets/shared/gabay_page_route.dart';
import '../../widgets/shared/gabay_tab_body.dart';
import 'caregiver_track.dart';
import 'caregiver_reports.dart';
import 'caregiver_profile.dart';
import 'notifications_page.dart';
import '../shared/information_health_status_page.dart';
import '../../models/navigator_health_profile.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  int _selectedIndex = 0;
  final _notificationService = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    _notificationService.addListener(_onNotificationsChanged);
    // Pull Users.name so the header shows a formal display name.
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    try {
      await ProfileService.instance.fetchProfile();
    } catch (_) {
      // Keep cached session name if offline.
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

  void _openNavigatorHealthStatus() {
    context.pushGabayPage(
      const InformationHealthStatusPage(
        profile: NavigatorHealthProfile.linkedNavigator,
      ),
    );
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
    final accent = context.gabay.accent;

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
            const SizedBox(height: 20),
            LiveStatusCard(
              onViewProfile: _openNavigatorHealthStatus,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.location_on_rounded,
                    title: 'Distance Covered',
                    value: '3243',
                    unit: 'Km',
                    color: accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: StatCard(
                    icon: Icons.route_rounded,
                    title: 'Total Route',
                    value: '23',
                    unit: 'Route',
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LocationCard(
              onViewMapPressed: () => _onNavTapped(1),
            ),
            const SizedBox(height: 22),
            Text(
              'Recent Activity',
              style: GabayTheme.sectionTitle(context),
            ),
            const SizedBox(height: 14),
            const RecentActivityList(),
          ],
        ),
      ),
    );
  }
}
