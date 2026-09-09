import 'package:flutter/material.dart';



import '../../models/linked_navigator.dart';

import '../../theme/gabay_theme.dart';



/// Bottom sheet for caregivers to switch between linked navigators.

class NavigatorMonitorSheet extends StatelessWidget {

  final List<LinkedNavigator> navigators;

  final String selectedId;

  final bool showAllOnMap;

  final ValueChanged<LinkedNavigator> onNavigatorSelected;

  final ValueChanged<bool> onShowAllChanged;



  const NavigatorMonitorSheet({

    super.key,

    required this.navigators,

    required this.selectedId,

    required this.showAllOnMap,

    required this.onNavigatorSelected,

    required this.onShowAllChanged,

  });



  static Future<void> show(

    BuildContext context, {

    required List<LinkedNavigator> navigators,

    required String selectedId,

    required bool showAllOnMap,

    required ValueChanged<LinkedNavigator> onNavigatorSelected,

    required ValueChanged<bool> onShowAllChanged,

  }) {

    return showModalBottomSheet<void>(

      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (context) {

        return NavigatorMonitorSheet(

          navigators: navigators,

          selectedId: selectedId,

          showAllOnMap: showAllOnMap,

          onNavigatorSelected: onNavigatorSelected,

          onShowAllChanged: onShowAllChanged,

        );

      },

    );

  }



  @override

  Widget build(BuildContext context) {

    final g = context.gabay;

    final onlineCount = navigators.where((n) => n.isOnline).length;



    return Container(

      constraints: BoxConstraints(

        maxHeight: MediaQuery.of(context).size.height * 0.72,

      ),

      decoration: BoxDecoration(

        color: g.surface,

        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),

      ),

      child: Column(

        mainAxisSize: MainAxisSize.min,

        children: [

          const SizedBox(height: 12),

          Container(

            width: 42,

            height: 4,

            decoration: BoxDecoration(

              color: g.border,

              borderRadius: BorderRadius.circular(4),

            ),

          ),

          Padding(

            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),

            child: Row(

              children: [

                Container(

                  padding: const EdgeInsets.all(10),

                  decoration: BoxDecoration(

                    color: g.accentTint,

                    borderRadius: BorderRadius.circular(14),

                  ),

                  child: Icon(

                    Icons.groups_rounded,

                    color: g.accent,

                  ),

                ),

                const SizedBox(width: 12),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(

                        'Monitor Navigators',

                        style: GabayTheme.sectionTitle(context).copyWith(fontSize: 18),

                      ),

                      Text(

                        '$onlineCount of ${navigators.length} online',

                        style: GabayTheme.bodyMedium(context).copyWith(fontSize: 13),

                      ),

                    ],

                  ),

                ),

              ],

            ),

          ),

          Padding(

            padding: const EdgeInsets.symmetric(horizontal: 20),

            child: Container(

              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),

              decoration: BoxDecoration(

                color: g.chipBackground,

                borderRadius: BorderRadius.circular(16),

              ),

              child: Row(

                children: [

                  Icon(

                    Icons.map_rounded,

                    color: g.accent,

                    size: 20,

                  ),

                  const SizedBox(width: 10),

                  Expanded(

                    child: Text(

                      'Show all on map',

                      style: GabayTheme.bodyLarge(context).copyWith(fontSize: 15),

                    ),

                  ),

                  Switch.adaptive(

                    value: showAllOnMap,

                    activeTrackColor: g.accent,

                    onChanged: onShowAllChanged,

                  ),

                ],

              ),

            ),

          ),

          const SizedBox(height: 12),

          Flexible(

            child: ListView.separated(

              shrinkWrap: true,

              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),

              itemCount: navigators.length,

              separatorBuilder: (_, _) => const SizedBox(height: 10),

              itemBuilder: (context, index) {

                final navigator = navigators[index];

                final isSelected = navigator.id == selectedId;



                return _NavigatorTile(

                  navigator: navigator,

                  isSelected: isSelected,

                  onTap: () {

                    onNavigatorSelected(navigator);

                    Navigator.pop(context);

                  },

                );

              },

            ),

          ),

        ],

      ),

    );

  }

}



class _NavigatorTile extends StatelessWidget {

  final LinkedNavigator navigator;

  final bool isSelected;

  final VoidCallback onTap;



  const _NavigatorTile({

    required this.navigator,

    required this.isSelected,

    required this.onTap,

  });



  @override

  Widget build(BuildContext context) {

    final g = context.gabay;

    final statusColor =

        navigator.isOnline ? g.success : g.textSecondary;



    return Material(

      color: isSelected ? g.accentTint : g.surface,

      borderRadius: BorderRadius.circular(18),

      child: InkWell(

        borderRadius: BorderRadius.circular(18),

        onTap: onTap,

        child: Container(

          padding: const EdgeInsets.all(14),

          decoration: BoxDecoration(

            borderRadius: BorderRadius.circular(18),

            border: Border.all(

              color: isSelected ? g.accent : g.border,

              width: isSelected ? 1.5 : 1,

            ),

          ),

          child: Row(

            children: [

              CircleAvatar(

                radius: 24,

                backgroundColor: g.accentTint,

                child: Text(

                  navigator.name.isNotEmpty

                      ? navigator.name[0].toUpperCase()

                      : '?',

                  style: TextStyle(

                    color: g.accent,

                    fontWeight: FontWeight.w800,

                    fontSize: 18,

                  ),

                ),

              ),

              const SizedBox(width: 12),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      navigator.name,

                      style: TextStyle(

                        fontWeight: FontWeight.w700,

                        fontSize: 15,

                        color: g.textPrimary,

                      ),

                    ),

                    const SizedBox(height: 2),

                    Text(

                      navigator.address,

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: GabayTheme.bodyMedium(context).copyWith(fontSize: 12),

                    ),

                    const SizedBox(height: 6),

                    Row(

                      children: [

                        Container(

                          width: 7,

                          height: 7,

                          decoration: BoxDecoration(

                            color: statusColor,

                            shape: BoxShape.circle,

                          ),

                        ),

                        const SizedBox(width: 6),

                        Text(

                          navigator.status,

                          style: TextStyle(

                            fontSize: 12,

                            fontWeight: FontWeight.w600,

                            color: statusColor,

                          ),

                        ),

                        const SizedBox(width: 12),

                        Icon(

                          Icons.battery_std_rounded,

                          size: 14,

                          color: g.textSecondary,

                        ),

                        const SizedBox(width: 4),

                        Text(

                          '${navigator.batteryPercent}%',

                          style: GabayTheme.labelSmall(context).copyWith(fontSize: 11),

                        ),

                      ],

                    ),

                  ],

                ),

              ),

              if (isSelected)

                Icon(

                  Icons.check_circle_rounded,

                  color: g.accent,

                )

              else

                Icon(

                  Icons.chevron_right_rounded,

                  color: g.textSecondary,

                ),

            ],

          ),

        ),

      ),

    );

  }

}



/// Compact button to open the navigator monitor sheet.

class NavigatorMonitorButton extends StatelessWidget {

  final int navigatorCount;

  final VoidCallback onPressed;



  const NavigatorMonitorButton({

    super.key,

    required this.navigatorCount,

    required this.onPressed,

  });



  @override

  Widget build(BuildContext context) {

    final g = context.gabay;



    return Material(

      color: g.heading,

      borderRadius: BorderRadius.circular(16),

      elevation: 4,

      shadowColor: g.shadow,

      child: InkWell(

        borderRadius: BorderRadius.circular(16),

        onTap: onPressed,

        child: Padding(

          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

          child: Row(

            mainAxisSize: MainAxisSize.min,

            children: [

              const Icon(Icons.groups_rounded, color: Colors.white, size: 20),

              const SizedBox(width: 8),

              Text(

                'Navigators ($navigatorCount)',

                style: const TextStyle(

                  color: Colors.white,

                  fontWeight: FontWeight.w700,

                  fontSize: 13,

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}

