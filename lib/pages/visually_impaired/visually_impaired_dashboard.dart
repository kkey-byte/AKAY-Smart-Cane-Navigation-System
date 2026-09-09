import 'package:flutter/material.dart';

import '../../models/linked_navigator.dart';
import '../../services/app_session_service.dart';
import '../../services/profile_service.dart';
import '../../services/vi_navigation_session.dart';
import '../../theme/gabay_theme.dart';
import '../../widgets/dashboard_widgets/activity_card.dart';
import '../../widgets/dashboard_widgets/bottom_nav.dart';
import '../../widgets/dashboard_widgets/dashboard_header.dart';
import '../../widgets/dashboard_widgets/location_card.dart';
import '../../widgets/dashboard_widgets/stat_card.dart';
import '../../widgets/shared/floating_bottom_nav_shell.dart';
import '../../widgets/shared/gabay_page_route.dart';
import '../../widgets/shared/gabay_tab_body.dart';
import '../../widgets/shared/gabay_card.dart';
import '../../widgets/visually_impaired/vi_navigation_banner.dart';
import '../../widgets/visually_impaired/vi_quick_action_tile.dart';
import '../../widgets/visually_impaired/vi_status_overview_card.dart';
import 'vi_notifications_page.dart';
import 'vi_voice_assistant_page.dart';
import 'visually_impaired_profile.dart';
import 'visually_impaired_reports.dart';
import 'visually_impaired_track.dart';

class VisuallyImpairedDashboard extends StatefulWidget {
  const VisuallyImpairedDashboard({super.key});

  @override
  State<VisuallyImpairedDashboard> createState() =>
      _VisuallyImpairedDashboardState();
}

class _VisuallyImpairedDashboardState extends State<VisuallyImpairedDashboard> {
  int _selectedIndex = 0;
  final _navigationSession = ViNavigationSession.instance;

  @override
  void initState() {
    super.initState();
    _navigationSession.addListener(_onNavigationSessionChanged);
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
      body: GabayTabBody(
        index: _selectedIndex,
        children: [
          _buildHomePage(context),
          const VisuallyImpairedTrackPage(),
          const VisuallyImpairedReportsPage(),
          const VisuallyImpairedProfilePage(),
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
    return 'Navigator';
  }

  Widget _buildHomePage(BuildContext context) {
    final accent = context.gabay.accent;
    final isNavigating = _navigationSession.isNavigating;
    final self = LinkedNavigatorService.selfNavigator;

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
                  label: 'Navigator: $name',
                  child: DashboardHeader(
                    greeting: 'Hello, Welcome back!',
                    name: name,
                    avatarAsset: null,
                    unreadCount: 1,
                    onNotificationTap: () =>
                        _pushPage(const ViNotificationsPage()),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ViNavigationBanner(
              isActive: isNavigating,
              onTap: _openTrackTab,
            ),
            const SizedBox(height: 16),
            ViStatusOverviewCard(
              batteryPercent: self.batteryPercent,
              statusLabel: isNavigating ? 'Walking' : self.status,
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
              navigatorName: self.name,
              isNavigating: isNavigating,
              onStartNavigationPressed: _openTrackTab,
              onViewMapPressed: _openTrackTab,
            ),
            const SizedBox(height: 22),
            Text('Quick Actions', style: GabayTheme.sectionTitle(context)),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                ViQuickActionTile(
                  icon: Icons.share_location_rounded,
                  label: 'Share Live Location',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Live location shared with caregiver'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                ViQuickActionTile(
                  icon: Icons.mic_rounded,
                  label: 'Voice Assistant',
                  onTap: () => _pushPage(const ViVoiceAssistantPage()),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text('Recent Activity', style: GabayTheme.sectionTitle(context)),
            const SizedBox(height: 14),
            GabayCard(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  ActivityCard(
                    color: accent,
                    icon: Icons.navigation_rounded,
                    title: 'Navigation started to City Hall',
                    time: '9:15 AM',
                    showDivider: true,
                  ),
                  ActivityCard(
                    color: accent,
                    icon: Icons.check_circle_rounded,
                    title: 'Destination reached: Public Market',
                    time: '8:40 AM',
                    showDivider: true,
                  ),
                  ActivityCard(
                    color: accent,
                    icon: Icons.battery_alert_rounded,
                    title: 'Cane battery low (20%)',
                    time: '7:55 AM',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
