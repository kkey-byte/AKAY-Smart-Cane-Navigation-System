import '../../widgets/shared/gabay_dashboard_backdrop.dart';
import 'package:flutter/material.dart';

import '../../services/app_session_service.dart';
import '../../services/profile_service.dart';
import '../../services/vi_navigation_session.dart';

import '../../widgets/dashboard_widgets/activity_card.dart';
import '../../widgets/dashboard_widgets/bottom_nav.dart';
import '../../widgets/dashboard_widgets/dashboard_header.dart';
import '../../widgets/dashboard_widgets/dashboard_live_section.dart';
import '../../widgets/shared/floating_bottom_nav_shell.dart';
import '../../widgets/shared/gabay_page_route.dart';
import '../../widgets/shared/gabay_tab_body.dart';
import 'vi_notifications_page.dart';
import 'visually_impaired_profile.dart';
import 'visually_impaired_reports.dart';
import '../screens/track_page.dart';

class VisuallyImpairedDashboard extends StatefulWidget {
  const VisuallyImpairedDashboard({super.key});

  @override
  State<VisuallyImpairedDashboard> createState() =>
      _VisuallyImpairedDashboardState();
}

class _VisuallyImpairedDashboardState extends State<VisuallyImpairedDashboard> {
  int _selectedIndex = 0;
  final _liveKey = GlobalKey<DashboardLiveSectionState>();
  Future<void> _refreshHome() async {
    await Future.wait([
      _loadDisplayName(),
      _liveKey.currentState?.refresh() ?? Future.value(),
    ]);
  }

  bool _profileLoading = true;
  bool _profileError = false;
  final _trackKey = GlobalKey<TrackPageState>();
  final _navigationSession = ViNavigationSession.instance;

  @override
  void initState() {
    super.initState();
    _navigationSession.addListener(_onNavigationSessionChanged);
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
    _navigationSession.removeListener(_onNavigationSessionChanged);
    super.dispose();
  }

  void _onNavigationSessionChanged() => setState(() {});

  void _onNavTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  void _openTrackTab() => _onNavTapped(1);

  void _pushPage(Widget page) {
    context.pushGabayPage(page);
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
            _buildHomePage(context),
            TrackPage(key: _trackKey, role: TrackPageRole.navigator),
            const VisuallyImpairedReportsPage(),
            const VisuallyImpairedProfilePage(),
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
    return 'Navigator';
  }

  Widget _buildHomePage(BuildContext context) {
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
                      label: 'Navigator: $name',
                      child: DashboardHeader(
                        glass: true,
                        greeting: 'Hello, Welcome back!',
                        name: name,
                        nameFontSize: 18,
                        nameFontWeight: FontWeight.w400,
                        avatarUrl: AppSessionService.instance.profilePicture,
                        unreadCount: 0,
                        onNotificationTap: () =>
                            _pushPage(const ViNotificationsPage()),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                DashboardLiveSection(
                  key: _liveKey,
                  caregiver: false,
                  onViewMap: _openTrackTab,
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
                const RecentActivityList(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
