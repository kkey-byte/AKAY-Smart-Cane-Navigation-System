import '../../widgets/shared/gabay_dashboard_backdrop.dart';
import 'package:flutter/material.dart';

import '../../models/gabay_notification.dart';
import '../../services/app_session_service.dart';
import '../../services/notification_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/dashboard_widgets/dashboard_header.dart';
import '../../widgets/dashboard_widgets/dashboard_live_section.dart';
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
  final _liveKey = GlobalKey<DashboardLiveSectionState>();
  final _activityNavigator = ValueNotifier<({String uid, String name})?>(null);
  Future<void> _refreshHome() async {
    await Future.wait([
      _loadDisplayName(),
      _liveKey.currentState?.refresh() ?? Future.value(),
    ]);
  }

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

  Future<void>? _profileRequest;
  Future<void> _loadDisplayName() => _profileRequest ??= _fetchDisplayName()
      .whenComplete(() => _profileRequest = null);
  Future<void> _fetchDisplayName() async {
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
    _activityNavigator.dispose();
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
      body: FloatingBottomNavLayout(
        body: GabayTabBody(
          index: _selectedIndex,
          children: [
            _buildDashboardPage(context),
            const TrackPage(),
            const ReportsPage(),
            const ProfilePage(),
          ],
        ),
        navigation: BottomNav(
          dashboard: _selectedIndex == 0,
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
    return GabayDashboardBackground(
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshHome,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                        avatarUrl: AppSessionService.instance.profilePicture,
                        greeting: 'Hello, Welcome back!',
                        name: name,
                        nameFontSize: 18,
                        nameFontWeight: FontWeight.w400,
                        unreadCount: _notificationService.unreadCount,
                        onNotificationTap: _openNotifications,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                DashboardLiveSection(
                  key: _liveKey,
                  caregiver: true,
                  onNavigatorChanged: (navigator) =>
                      _activityNavigator.value = navigator,
                  onViewMap: () => _onNavTapped(1),
                ),
                const SizedBox(height: 16),
                if (_profileLoading)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Loading profile',
                  ),
                if (_profileError)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Profile refresh failed. Cached details may be out of date.',
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor:
                              GabayDashboardBackdrop.secondaryColor(context),
                        ),
                        onPressed: _loadDisplayName,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Text(
                  'Recent Activity',
                  style: GabayDashboardBackdrop.headingStyle(context),
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<({String uid, String name})?>(
                  valueListenable: _activityNavigator,
                  builder: (context, navigator, _) => RecentActivityList(
                    caregiver: true,
                    ownerId: navigator?.uid,
                    navigatorName: navigator?.name,
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
