import 'package:flutter/material.dart';



import '../../theme/gabay_theme.dart';



class ActivityCard extends StatelessWidget {

  final Color color;

  final IconData icon;

  final String title;

  final String time;

  final bool showDivider;



  const ActivityCard({

    super.key,

    required this.color,

    required this.icon,

    required this.title,

    required this.time,

    this.showDivider = false,

  });



  @override

  Widget build(BuildContext context) {

    final g = context.gabay;



    return Column(

      children: [

        Padding(

          padding: const EdgeInsets.symmetric(vertical: 14),

          child: Row(

            children: [

              Container(

                width: 46,

                height: 46,

                decoration: BoxDecoration(

                  color: color.withValues(alpha: 0.12),

                  borderRadius: BorderRadius.circular(14),

                ),

                child: Icon(icon, color: color, size: 24),

              ),

              const SizedBox(width: 14),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      title,

                      style: TextStyle(

                        fontWeight: FontWeight.w700,

                        fontSize: 15,

                        color: g.textPrimary,

                      ),

                    ),

                    const SizedBox(height: 3),

                    Text(

                      'Today • $time',

                      style: TextStyle(

                        color: g.textSecondary,

                        fontSize: 13,

                        fontWeight: FontWeight.w500,

                      ),

                    ),

                  ],

                ),

              ),

            ],

          ),

        ),

        if (showDivider)

          Divider(height: 1, color: g.border),

      ],

    );

  }

}



class RecentActivityList extends StatelessWidget {

  const RecentActivityList({super.key});



  @override

  Widget build(BuildContext context) {

    final g = context.gabay;



    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: GabayTheme.cardDecoration(context),
      child: Column(
        children: [
          ActivityCard(
            color: g.accent,
            icon: Icons.error_outline_rounded,
            title: 'Obstacle detected',
            time: '10:40 AM',
            showDivider: true,
          ),
          ActivityCard(
            color: g.accent,
            icon: Icons.check_circle_outline_rounded,
            title: 'Destination reached',
            time: '10:40 AM',
            showDivider: true,
          ),
          ActivityCard(
            color: g.accent,
            icon: Icons.battery_alert_rounded,
            title: 'Battery low (20%)',
            time: '9:20 AM',
            showDivider: true,
          ),
          ActivityCard(
            color: g.accent,
            icon: Icons.navigation_rounded,
            title: 'Navigation started',
            time: '10:40 AM',
          ),
        ],
      ),
    );

  }

}

