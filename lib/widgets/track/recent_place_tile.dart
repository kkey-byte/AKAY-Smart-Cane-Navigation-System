import 'package:flutter/material.dart';



import '../../models/route_plan.dart';

import '../../theme/gabay_theme.dart';



class RecentPlaceTile extends StatelessWidget {

  final MapPlace place;

  final VoidCallback onTap;



  const RecentPlaceTile({

    super.key,

    required this.place,

    required this.onTap,

  });



  @override

  Widget build(BuildContext context) {

    final g = context.gabay;



    return Padding(

      padding: const EdgeInsets.only(bottom: 10),

      child: Material(

        color: g.surface,

        borderRadius: BorderRadius.circular(18),

        child: InkWell(

          borderRadius: BorderRadius.circular(18),

          onTap: onTap,

          child: Container(

            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(

              borderRadius: BorderRadius.circular(18),

              border: Border.all(color: g.border),

            ),

            child: Row(

              children: [

                Container(

                  width: 46,

                  height: 46,

                  decoration: BoxDecoration(

                    color: g.accentTint,

                    borderRadius: BorderRadius.circular(14),

                  ),

                  child: Icon(

                    Icons.location_on_outlined,

                    color: g.accent,

                  ),

                ),

                const SizedBox(width: 14),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(

                        place.name,

                        style: TextStyle(

                          fontWeight: FontWeight.w700,

                          fontSize: 15,

                          color: g.textPrimary,

                        ),

                      ),

                      const SizedBox(height: 3),

                      Text(

                        place.address,

                        style: GabayTheme.bodyMedium(context).copyWith(fontSize: 13),

                      ),

                    ],

                  ),

                ),

                if (place.distance != null)

                  Text(

                    place.distance!,

                    style: TextStyle(

                      color: g.accent,

                      fontWeight: FontWeight.w700,

                      fontSize: 13,

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

