import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';
import '../shared/floating_bottom_nav_shell.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Semantics(
      container: true,
      label: 'Main navigation',
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          GabayNavMetrics.horizontalMargin,
          0,
          GabayNavMetrics.horizontalMargin,
          GabayNavMetrics.bottomMargin,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: g.surface,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: g.shadow,
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
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
    );
  }

  Widget _navItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final g = context.gabay;
    final selected = currentIndex == index;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: () => onIndexChanged(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 18 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: selected ? g.accentTint : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 300),
                scale: selected ? 1.1 : 1,
                child: Icon(
                  icon,
                  size: 25,
                  color: selected ? g.accent : g.textSecondary,
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            color: g.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
