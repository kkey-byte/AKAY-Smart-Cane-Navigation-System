import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';

const mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

class LocationCard extends StatelessWidget {
  final String navigatorName;

  final double latitude;

  final double longitude;

  final VoidCallback? onViewMapPressed;

  /// When false, the map action shows "Start Navigation". When true, "View Map".
  final bool isNavigating;

  /// Called when the user taps "Start Navigation" (navigator home only).
  final VoidCallback? onStartNavigationPressed;

  const LocationCard({
    super.key,

    this.navigatorName = 'Glaisa Regine Mariel',

    this.latitude = 7.3081,

    this.longitude = 125.6842,

    this.onViewMapPressed,

    this.isNavigating = false,

    this.onStartNavigationPressed,
  });

  bool get _usesNavigationToggle => onStartNavigationPressed != null;

  String get _actionLabel {
    if (!_usesNavigationToggle) return 'View Map';
    return isNavigating ? 'View Map' : 'Start Navigation';
  }

  VoidCallback? get _actionHandler {
    if (!_usesNavigationToggle) return onViewMapPressed;
    return isNavigating ? onViewMapPressed : onStartNavigationPressed;
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Container(
      height: 240,
      decoration: GabayTheme.cardDecoration(
        context,
      ).copyWith(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),

        child: Stack(
          fit: StackFit.expand,

          children: [
            Image.network(
              'https://api.mapbox.com/styles/v1/mapbox/light-v11/static/$longitude,$latitude,13/600x300?access_token=$mapboxToken',

              fit: BoxFit.cover,

              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(color: g.mapPlaceholder),

                  child: Center(
                    child: Icon(
                      Icons.map_outlined,

                      size: 56,

                      color: g.textSecondary,
                    ),
                  ),
                );
              },
            ),

            Positioned(
              top: 18,

              left: 18,

              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),

                decoration: BoxDecoration(
                  color: g.surface,

                  borderRadius: BorderRadius.circular(20),

                  boxShadow: [
                    BoxShadow(
                      color: g.shadow,

                      blurRadius: 8,

                      offset: const Offset(0, 2),
                    ),
                  ],
                ),

                child: Row(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Container(
                      width: 22,

                      height: 22,

                      decoration: BoxDecoration(
                        color: g.accent,

                        borderRadius: BorderRadius.circular(6),
                      ),

                      child: const Icon(
                        Icons.location_on_rounded,

                        color: Colors.white,

                        size: 14,
                      ),
                    ),

                    const SizedBox(width: 8),

                    Text(
                      navigatorName,

                      style: TextStyle(
                        color: g.accent,

                        fontSize: 13,

                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              right: 16,

              bottom: 16,

              child: Material(
                color: g.accent,

                borderRadius: BorderRadius.circular(24),

                elevation: 4,

                shadowColor: g.accent.withValues(alpha: 0.35),

                child: InkWell(
                  borderRadius: BorderRadius.circular(24),

                  onTap: _actionHandler,

                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),

                    child: Row(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        Text(
                          _actionLabel,

                          style: const TextStyle(
                            color: Colors.white,

                            fontSize: 15,

                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(width: 6),

                        Icon(
                          isNavigating || !_usesNavigationToggle
                              ? Icons.arrow_forward_rounded
                              : Icons.navigation_rounded,

                          color: Colors.white,

                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
