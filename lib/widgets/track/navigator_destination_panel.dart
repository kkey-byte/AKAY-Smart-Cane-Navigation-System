import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/route_plan.dart';
import '../../models/search_destination.dart';
import '../../theme/gabay_theme.dart';

/// Destination search panel for navigator Track mode.
/// Same placement/structure as before — polished MD3 styling only.
class NavigatorDestinationPanel extends StatelessWidget {
  const NavigatorDestinationPanel({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.suggestions,
    required this.isNavigating,
    required this.isSearching,
    required this.onChanged,
    required this.onSubmitted,
    required this.onSearchTap,
    required this.onSuggestionTap,
    required this.onClear,
    required this.categories,
    required this.onCategorySelected,
    required this.recentQueries,
    required this.onRecentSelected,
    required this.onSpeakPlace,
    required this.onNavigatePlace,
    this.activeDestinationName,
    this.onCancelNavigation,
    this.showPinHint = false,
    this.isResolvingPin = false,
    this.showEmptyState = false,
    this.onSearchWider,
    this.onVoiceSearch,
    this.selectedCategoryQuery,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<MapPlace> suggestions;
  final bool isNavigating;
  final bool isSearching;
  final String? activeDestinationName;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearchTap;
  final ValueChanged<MapPlace> onSuggestionTap;
  final VoidCallback onClear;
  final VoidCallback? onCancelNavigation;
  final bool showPinHint;
  final bool isResolvingPin;
  final List<SearchCategory> categories;
  final ValueChanged<SearchCategory> onCategorySelected;
  final List<String> recentQueries;
  final ValueChanged<String> onRecentSelected;
  final ValueChanged<MapPlace> onSpeakPlace;
  final ValueChanged<MapPlace> onNavigatePlace;
  final bool showEmptyState;
  final VoidCallback? onSearchWider;
  final VoidCallback? onVoiceSearch;
  final String? selectedCategoryQuery;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SearchBarCard(
          controller: controller,
          focusNode: focusNode,
          isNavigating: isNavigating,
          isSearching: isSearching || isResolvingPin,
          activeDestinationName: activeDestinationName,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          onSearchTap: onSearchTap,
          onClear: onClear,
          onVoiceSearch: onVoiceSearch,
        ),
        if (!isNavigating) ...[
          const SizedBox(height: 10),
          _CategoryChips(
            categories: categories,
            selectedQuery: selectedCategoryQuery,
            onSelected: onCategorySelected,
          ),
          if (showPinHint &&
              suggestions.isEmpty &&
              !isSearching &&
              !showEmptyState) ...[
            const SizedBox(height: 8),
            Text(
              'Search nearby places, or tap the map to pin a destination.',
              style: TextStyle(
                color: g.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
          if (!isSearching &&
              recentQueries.isNotEmpty &&
              suggestions.isEmpty &&
              controller.text.trim().isEmpty) ...[
            const SizedBox(height: 8),
            _RecentSearches(
              queries: recentQueries,
              onSelected: onRecentSelected,
            ),
          ],
          if (showEmptyState && !isSearching) ...[
            const SizedBox(height: 8),
            _EmptySearchState(onSearchWider: onSearchWider),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SuggestionList(
              suggestions: suggestions,
              onTap: onSuggestionTap,
              onSpeak: onSpeakPlace,
              onNavigate: onNavigatePlace,
            ),
          ],
        ],
        if (isNavigating && onCancelNavigation != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onCancelNavigation,
              style: TextButton.styleFrom(
                foregroundColor: g.danger,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(48, 44),
              ),
              icon: Icon(Icons.stop_circle_outlined, color: g.danger, size: 20),
              label: Text(
                'End navigation',
                style: TextStyle(
                  color: g.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchBarCard extends StatelessWidget {
  const _SearchBarCard({
    required this.controller,
    required this.focusNode,
    required this.isNavigating,
    required this.isSearching,
    required this.onChanged,
    required this.onSubmitted,
    required this.onSearchTap,
    required this.onClear,
    this.activeDestinationName,
    this.onVoiceSearch,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isNavigating;
  final bool isSearching;
  final String? activeDestinationName;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearchTap;
  final VoidCallback onClear;
  final VoidCallback? onVoiceSearch;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Material(
      color: g.surface,
      elevation: 3,
      shadowColor: g.shadow,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
        child: Row(
          children: [
            if (isNavigating) Semantics(
              label: isNavigating
                  ? 'Currently navigating'
                  : 'Your current location',
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: g.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: g.accent.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  isNavigating
                      ? Icons.directions_walk_rounded
                      : Icons.my_location_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            if (isNavigating) const SizedBox(width: 10),
            Expanded(
              child: isNavigating
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeDestinationName ?? 'Destination',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: g.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Navigating',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: g.success,
                          ),
                        ),
                      ],
                    )
                  : Semantics(
                      label: 'Destination search field',
                      textField: true,
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: onChanged,
                        onSubmitted: onSubmitted,
                        textInputAction: TextInputAction.search,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: g.textPrimary,
                          letterSpacing: -0.1,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText:
                              'Search hospitals, schools, restaurants, landmarks...',
                          hintStyle: TextStyle(
                            color: g.textSecondary.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                            fontSize: 13.5,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
            ),
            if (isSearching)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              )
            else if (isNavigating)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: g.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'LIVE',
                  style: TextStyle(
                    color: g.success,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.4,
                  ),
                ),
              )
            else ...[
              if (controller.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: Icon(Icons.close_rounded, color: g.textSecondary),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
              if (onVoiceSearch != null)
                IconButton(
                  tooltip: 'Voice search (coming soon)',
                  onPressed: onVoiceSearch,
                  icon: Icon(
                    Icons.mic_none_rounded,
                    color: g.textSecondary.withValues(alpha: 0.85),
                  ),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
              IconButton(
                tooltip: 'Search destination',
                onPressed: onSearchTap,
                icon: Icon(Icons.search_rounded, color: g.accent, size: 26),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.onSelected,
    this.selectedQuery,
  });

  final List<SearchCategory> categories;
  final ValueChanged<SearchCategory> onSelected;
  final String? selectedQuery;

  IconData _iconFor(String key) {
    switch (key) {
      case 'local_hospital':
        return Icons.local_hospital_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'atm':
        return Icons.atm_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'local_police':
        return Icons.local_police_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'church':
        return Icons.church_rounded;
      case 'store_mall_directory':
        return Icons.store_mall_directory_rounded;
      case 'storefront':
        return Icons.storefront_rounded;
      case 'directions_bus':
        return Icons.directions_bus_rounded;
      case 'hotel':
        return Icons.hotel_rounded;
      case 'park':
        return Icons.park_rounded;
      case 'local_pharmacy':
        return Icons.local_pharmacy_rounded;
      case 'attractions':
        return Icons.attractions_rounded;
      case 'local_gas_station':
        return Icons.local_gas_station_rounded;
      case 'home_work':
        return Icons.home_work_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Semantics(
      label: 'Nearby place categories',
      child: SizedBox(
        height: 40,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse,
              PointerDeviceKind.stylus, PointerDeviceKind.trackpad},
          ),
          child: ListView.separated(
          primary: false,
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final cat = categories[index];
            final selected = selectedQuery == cat.query;
            return FilterChip(
              selected: selected,
              showCheckmark: false,
              avatar: Icon(
                _iconFor(cat.icon),
                size: 18,
                color: selected ? Colors.white : g.accent,
              ),
              label: Text(
                cat.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: selected ? Colors.white : g.textPrimary,
                ),
              ),
              selectedColor: g.accent,
              backgroundColor: g.chipBackground,
              side: BorderSide(
                color: selected ? g.accent : g.border.withValues(alpha: 0.8),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                onSelected(cat);
              },
            );
          },
          ),
        ),
      ),
    );
  }
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.queries,
    required this.onSelected,
  });

  final List<String> queries;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Material(
      color: g.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent searches',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: g.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            ...queries.take(5).map(
              (q) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                minVerticalPadding: 0,
                leading: Icon(Icons.history_rounded, color: g.textSecondary, size: 20),
                title: Text(
                  q,
                  style: TextStyle(
                    color: g.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                onTap: () => onSelected(q),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({this.onSearchWider});

  final VoidCallback? onSearchWider;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Material(
      color: g.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, color: g.textSecondary, size: 28),
            const SizedBox(height: 8),
            Text(
              'No nearby destination found.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: g.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try another keyword or search a wider area.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: g.textSecondary,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            if (onSearchWider != null) ...[
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: onSearchWider,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(160, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Search Wider Area'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    required this.suggestions,
    required this.onTap,
    required this.onSpeak,
    required this.onNavigate,
  });

  final List<MapPlace> suggestions;
  final ValueChanged<MapPlace> onTap;
  final ValueChanged<MapPlace> onSpeak;
  final ValueChanged<MapPlace> onNavigate;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final count = suggestions.length.clamp(0, 8);

    return Material(
      color: g.surface,
      elevation: 3,
      shadowColor: g.shadow,
      borderRadius: BorderRadius.circular(18),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, _) => Divider(height: 1, color: g.border),
        itemBuilder: (context, index) {
          final place = suggestions[index];
          return _DestinationResultCard(
            place: place,
            onTap: () => onTap(place),
            onSpeak: () => onSpeak(place),
            onNavigate: () => onNavigate(place),
          );
        },
      ),
    );
  }
}

class _DestinationResultCard extends StatelessWidget {
  const _DestinationResultCard({
    required this.place,
    required this.onTap,
    required this.onSpeak,
    required this.onNavigate,
  });

  final MapPlace place;
  final VoidCallback onTap;
  final VoidCallback onSpeak;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final category = place.category ?? 'Place';
    final source = place.source ?? 'OpenStreetMap';
    final walk = place.walkingTime;
    final distance = place.distance;

    return Semantics(
      button: true,
      label:
          '${place.name}. $category. ${distance ?? ''}. ${walk ?? ''}. Source $source.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: place.isAccessible
                      ? g.success.withValues(alpha: 0.14)
                      : g.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  place.isAccessible
                      ? Icons.accessible_rounded
                      : Icons.place_rounded,
                  color: place.isAccessible ? g.success : g.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: g.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Badge(
                          label: category,
                          color: g.accent,
                          bg: g.accent.withValues(alpha: 0.12),
                        ),
                        _Badge(
                          label: source,
                          color: source == 'AKAY' ? g.success : g.textSecondary,
                          bg: (source == 'AKAY' ? g.success : g.textSecondary)
                              .withValues(alpha: 0.12),
                        ),
                        if (place.isAccessible)
                          _Badge(
                            label: 'Accessible',
                            color: g.success,
                            bg: g.success.withValues(alpha: 0.12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      place.shortAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: g.textSecondary,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                    if (distance != null || walk != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (distance != null && distance.isNotEmpty) distance,
                          if (walk != null && walk.isNotEmpty) walk,
                        ].join(' · '),
                        style: TextStyle(
                          color: g.heading,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    tooltip: 'Speak destination details',
                    onPressed: onSpeak,
                    icon: Icon(Icons.volume_up_rounded, color: g.accent),
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                  IconButton(
                    tooltip: 'Navigate to destination',
                    onPressed: onNavigate,
                    icon: Icon(Icons.directions_rounded, color: g.accent),
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.bg,
  });

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
