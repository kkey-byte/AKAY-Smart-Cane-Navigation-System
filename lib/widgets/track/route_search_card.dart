import '../../theme/gabay_typography.dart';
import 'readable_place_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../shared/gabay_selection_dialog.dart';

import '../../models/linked_navigator.dart';

import '../../models/route_plan.dart';

import '../../theme/gabay_theme.dart';

/// Route planner search UI — caregiver picks a Navigator and sets their destination.

class RouteSearchCard extends StatelessWidget {
  final List<LinkedNavigator> navigators;

  final LinkedNavigator selectedNavigator;

  final ValueChanged<LinkedNavigator> onNavigatorChanged;

  final TextEditingController destinationController;

  final FocusNode destinationFocusNode;

  final VoidCallback onSwap;

  final List<MapPlace> suggestions;

  final ValueChanged<MapPlace> onSuggestionSelected;

  final bool showNavigatorPicker;

  /// Shown as the origin ("Your current location") instead of mock navigator address.
  final String? originAddress;

  final String? originTitle;

  final bool isSearching;
  final VoidCallback? onSearch;

  const RouteSearchCard({
    super.key,

    required this.navigators,

    required this.selectedNavigator,

    required this.onNavigatorChanged,

    required this.destinationController,

    required this.destinationFocusNode,

    required this.onSwap,

    required this.suggestions,

    required this.onSuggestionSelected,

    this.showNavigatorPicker = true,

    this.originAddress,

    this.originTitle,

    this.isSearching = false,
    this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        if (showNavigatorPicker)
          _navigatorCard(context)
        else
          _originCard(context),

        const SizedBox(height: 14),

        _routeDetailsCard(context),

        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),

          _suggestionsList(context),
        ],
        if (kIsWeb &&
            ReadablePlaceText.coordinates(
                  originAddress ?? selectedNavigator.address,
                ) !=
                null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Location names © OpenStreetMap contributors',
              style: TextStyle(
                color: context.gabay.textSecondary,
                fontSize: GabayTypography.chartLabel,
              ),
            ),
          ),
      ],
    );
  }

  Widget _navigatorCard(BuildContext context) {
    final g = context.gabay;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),

      decoration: GabayTheme.cardDecoration(context),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            'Send destination to',

            style: GabayTheme.labelSmall(
              context,
            ).copyWith(color: g.accent, fontWeight: GabayTypography.medium),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              CircleAvatar(
                radius: 18,

                backgroundColor: g.accentTint,

                child: Text(
                  selectedNavigator.name.isNotEmpty
                      ? selectedNavigator.name[0].toUpperCase()
                      : '?',

                  style: TextStyle(
                    color: g.accent,

                    fontWeight: GabayTypography.medium,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: DropdownButtonHideUnderline(
                  child: GabayDropdownFormField<LinkedNavigator>(
                    dialogTitle: 'Choose Navigator',
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                    ),
                    value: selectedNavigator,

                    isExpanded: true,

                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,

                      color: g.textSecondary,

                      size: 22,
                    ),

                    hint: Text(
                      'Choose Navigator',

                      style: TextStyle(
                        color: g.textSecondary,

                        fontSize: GabayTypography.cardBody,

                        fontWeight: GabayTypography.medium,
                      ),
                    ),

                    style: TextStyle(
                      color: g.textPrimary,

                      fontSize: GabayTypography.cardBody,

                      fontWeight: GabayTypography.medium,
                    ),

                    items: navigators
                        .map(
                          (navigator) => DropdownMenuItem(
                            value: navigator,

                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              mainAxisSize: MainAxisSize.min,

                              children: [
                                Text(navigator.name),

                                Text(
                                  navigator.isOnline
                                      ? '${navigator.status} • ${navigator.batteryPercent}% battery'
                                      : 'Offline',

                                  style: TextStyle(
                                    fontSize: GabayTypography.caption,

                                    color: navigator.isOnline
                                        ? g.success
                                        : g.textSecondary,

                                    fontWeight: GabayTypography.medium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),

                    onChanged: (value) {
                      if (value != null) onNavigatorChanged(value);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _originCard(BuildContext context) {
    final g = context.gabay;

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: GabayTheme.cardDecoration(context),

      child: Row(
        children: [
          CircleAvatar(
            radius: 22,

            backgroundColor: g.accentTint,

            child: Icon(Icons.my_location_rounded, color: g.accent, size: 22),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'Starting point',

                  style: GabayTheme.labelSmall(context).copyWith(
                    color: g.accent,
                    fontWeight: GabayTypography.medium,
                  ),
                ),

                const SizedBox(height: 6),

                ReadablePlaceText(
                  showCoordinateFallback: false,
                  originAddress?.trim().isNotEmpty == true
                      ? originAddress!
                      : 'Locating you…',

                  style: TextStyle(
                    color: g.textPrimary,
                    fontSize: GabayTypography.body,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeDetailsCard(BuildContext context) {
    final g = context.gabay;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),

      curve: Curves.easeOutCubic,

      decoration: GabayTheme.cardDecoration(context).copyWith(
        border: destinationFocusNode.hasFocus
            ? Border.all(color: g.accent.withValues(alpha: 0.4))
            : null,
      ),

      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            Expanded(
              child: Column(
                children: [
                  if (showNavigatorPicker) _originRow(context),

                  if (showNavigatorPicker) Divider(height: 1, color: g.border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Destination',
                        style: GabayTheme.sectionTitle(context),
                      ),
                    ),
                  ),

                  _destinationRow(context),
                ],
              ),
            ),

            if (showNavigatorPicker)
              Container(
                width: 48,

                alignment: Alignment.center,

                child: IconButton(
                  onPressed: onSwap,

                  icon: Icon(
                    Icons.swap_vert_rounded,

                    color: g.textSecondary,

                    size: 26,
                  ),

                  tooltip: 'Swap origin and destination',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _originRow(BuildContext context) {
    final g = context.gabay;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 0, 14),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),

            child: Icon(
              Icons.location_on_outlined,

              color: g.accent.withValues(alpha: 0.9),

              size: 24,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  originTitle ??
                      (showNavigatorPicker
                          ? "${selectedNavigator.name}'s Location"
                          : 'Your current location'),

                  style: TextStyle(
                    fontSize: GabayTypography.caption,

                    color: g.textSecondary,

                    fontWeight: GabayTypography.medium,
                  ),
                ),

                const SizedBox(height: 3),

                ReadablePlaceText(
                  showCoordinateFallback: false,
                  originAddress?.trim().isNotEmpty == true
                      ? originAddress!
                      : 'Locating you…',

                  style: TextStyle(
                    fontSize: GabayTypography.cardBody,

                    fontWeight: GabayTypography.medium,

                    color: g.textPrimary,

                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _destinationRow(BuildContext context) {
    final g = context.gabay;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),

      child: Row(
        children: [
          Icon(
            Icons.search_rounded,

            color: g.accent.withValues(alpha: 0.9),

            size: 24,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: TextField(
              controller: destinationController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch?.call(),

              focusNode: destinationFocusNode,

              decoration: InputDecoration(
                hintText: 'Search destination',
                suffixIcon: IconButton(
                  tooltip: 'Search destinations',
                  onPressed: isSearching ? null : onSearch,
                  icon: const Icon(Icons.search),
                ),

                hintStyle: TextStyle(
                  color: g.textSecondary,

                  fontSize: GabayTypography.cardBody,

                  fontWeight: GabayTypography.medium,
                ),

                border: InputBorder.none,

                isDense: true,

                contentPadding: EdgeInsets.zero,
              ),

              style: TextStyle(
                fontSize: GabayTypography.cardBody,

                fontWeight: GabayTypography.medium,

                color: g.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionsList(BuildContext context) {
    final g = context.gabay;

    return Container(
      decoration: BoxDecoration(
        color: g.surface,

        borderRadius: BorderRadius.circular(16),

        boxShadow: [
          BoxShadow(
            color: g.shadow,

            blurRadius: 16,

            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: suggestions.take(4).map((place) {
            return ListTile(
              dense: true,

              leading: Icon(
                Icons.place_outlined,

                color: g.accent.withValues(alpha: 0.85),
              ),

              title: Text(
                place.displayName,

                style: TextStyle(
                  fontWeight: GabayTypography.medium,

                  fontSize: GabayTypography.body,

                  color: g.textPrimary,
                ),
              ),

              subtitle: Text(
                [
                  if (place.distance != null && place.distance!.isNotEmpty)
                    place.distance!,
                  if (place.walkingTime != null &&
                      place.walkingTime!.isNotEmpty)
                    place.walkingTime!,
                  if (place.source != null && place.source!.isNotEmpty)
                    place.source!,
                  place.shortAddress,
                ].join(' • '),

                maxLines: 2,

                overflow: TextOverflow.ellipsis,

                style: TextStyle(
                  fontSize: GabayTypography.caption,
                  color: g.textSecondary,
                ),
              ),

              onTap: () => onSuggestionSelected(place),
            );
          }).toList(),
        ),
      ),
    );
  }
}
