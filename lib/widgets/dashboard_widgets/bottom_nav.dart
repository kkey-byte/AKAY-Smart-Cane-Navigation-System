import '../../theme/gabay_typography.dart';
import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';
import '../shared/floating_bottom_nav_shell.dart';
import '../shared/gabay_glass_surface.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    this.dashboard = false,
  });
  final bool dashboard;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Main navigation',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          GabayNavMetrics.horizontalMargin,
          0,
          GabayNavMetrics.horizontalMargin,
          GabayNavMetrics.bottomMargin,
        ),
        child: GabayGlassSurface(
          dashboard: dashboard,
          radius: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _navItem(
                  context,
                  index: 0,
                  icon: Icons.home_outlined,
                  label: 'Home',
                ),
                _navItem(
                  context,
                  index: 1,
                  icon: Icons.directions_walk_outlined,
                  label: 'Track',
                ),
                _navItem(
                  context,
                  index: 2,
                  icon: Icons.insert_chart_outlined,
                  label: 'Reports',
                ),
                _navItem(
                  context,
                  index: 3,
                  icon: Icons.person_outline,
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final g = context.gabay;
    final darkDashboard =
        dashboard && Theme.of(context).brightness == Brightness.dark;
    final selected = currentIndex == index;
    final showLabel =
        selected &&
        MediaQuery.textScalerOf(context).scale(13) <= 20 &&
        MediaQuery.sizeOf(context).width >= 350;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: () => onIndexChanged(index),
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: selected ? 16 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? (dashboard
                        ? (darkDashboard
                              ? const Color(0xFF24456B)
                              : const Color(0xFFDBEAFE))
                        : g.accentTint)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 300),
                  scale: selected ? 1.1 : 1,
                  child: Icon(
                    icon,
                    size: 23,
                    color: selected
                        ? (dashboard
                              ? (darkDashboard
                                    ? const Color(0xFFBFDBFE)
                                    : const Color(0xFF2563EB))
                              : g.accent)
                        : (dashboard
                              ? (darkDashboard
                                    ? g.textSecondary
                                    : const Color(0xFF31557E))
                              : g.textSecondary),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: showLabel
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: GabayTypography.supporting,
                              color: dashboard
                                  ? (darkDashboard
                                        ? const Color(0xFFBFDBFE)
                                        : const Color(0xFF2563EB))
                                  : g.accent,
                              fontWeight: GabayTypography.medium,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
