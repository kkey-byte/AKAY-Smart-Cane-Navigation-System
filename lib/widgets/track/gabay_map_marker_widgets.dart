import 'package:flutter/material.dart';

import '../../utils/gabay_map_rendering.dart';
import 'gabay_map_marker.dart';

class GabayGlowDotMarker extends StatelessWidget {
  const GabayGlowDotMarker({
    super.key,
    required this.color,
    this.hollowCenter = false,
    this.size = 48,
  });

  final Color color;
  final bool hollowCenter;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.72,
            height: size * 0.72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          Container(
            width: size * 0.32,
            height: size * 0.32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: hollowCenter
                ? Center(
                    child: Container(
                      width: size * 0.12,
                      height: size * 0.12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class GabayNavigationArrowMarker extends StatelessWidget {
  const GabayNavigationArrowMarker({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.72,
            height: size * 0.72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: GabayMapRendering.routeAccent.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          Container(
            width: size * 0.36,
            height: size * 0.36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: GabayMapRendering.routeAccent,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              Icons.navigation_rounded,
              color: Colors.white,
              size: size * 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

Widget gabayMarkerWidgetForKind(
  GabayMapMarkerKind kind, {
  Color? genericColor,
}) {
  switch (kind) {
    case GabayMapMarkerKind.routeStart:
      return const GabayGlowDotMarker(color: GabayMapRendering.routeAccent);
    case GabayMapMarkerKind.routeProgress:
      return const GabayNavigationArrowMarker();
    case GabayMapMarkerKind.destination:
      return const GabayGlowDotMarker(
        color: GabayMapRendering.destinationColor,
        hollowCenter: true,
      );
    case GabayMapMarkerKind.navigator:
      return const GabayGlowDotMarker(
        color: Color(0xFF34C759),
        size: 42,
      );
    case GabayMapMarkerKind.caregiver:
      return const GabayGlowDotMarker(
        color: Color(0xFF8E8E93),
        size: 40,
      );
    case GabayMapMarkerKind.generic:
      return GabayGlowDotMarker(
        color: genericColor ?? GabayMapRendering.routeAccent,
        size: 40,
      );
  }
}
