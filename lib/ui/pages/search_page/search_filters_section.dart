import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/ui/components/filter_dropdown.dart';
import 'package:senpwai/ui/pages/search_page/search_filter_chips.dart';
import 'package:senpwai/ui/shared/anilist.dart';

class SearchFiltersSection extends ConsumerWidget {
  final TextEditingController searchController;
  final bool filtersExpanded;
  final double horizontalPadding;
  final List<AnilistGenre> genres;
  final List<AnilistAiringStatus> airingStatuses;
  final AnilistMediaListStatus? listStatus;
  final AnilistSeason? season;
  final int? year;
  final List<AnilistFormat> formats;
  final bool isListFilterActive;
  final ValueChanged<bool> onFiltersExpandedChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<List<AnilistGenre>> onGenresChanged;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<AnilistSeason?> onSeasonChanged;
  final ValueChanged<List<AnilistFormat>> onFormatsChanged;
  final ValueChanged<List<AnilistAiringStatus>> onAiringStatusesChanged;
  final ValueChanged<AnilistMediaListStatus?> onListStatusChanged;

  const SearchFiltersSection({
    super.key,
    required this.searchController,
    required this.filtersExpanded,
    required this.horizontalPadding,
    required this.genres,
    required this.airingStatuses,
    required this.listStatus,
    required this.season,
    required this.year,
    required this.formats,
    this.isListFilterActive = false,
    required this.onFiltersExpandedChanged,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onGenresChanged,
    required this.onYearChanged,
    required this.onSeasonChanged,
    required this.onFormatsChanged,
    required this.onAiringStatusesChanged,
    required this.onListStatusChanged,
  });

  int get _activeFilterCount {
    int count = 0;
    count += genres.length;
    count += airingStatuses.length;
    count += formats.length;
    if (listStatus != null) count++;
    if (season != null) count++;
    if (year != null) count++;
    return count;
  }

  void _clearAllFilters() {
    onGenresChanged(const []);
    onAiringStatusesChanged(const []);
    onFormatsChanged(const []);
    onListStatusChanged(null);
    onSeasonChanged(null);
    onYearChanged(null);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(AnilistNotifier.provider).isAuthenticated;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentYear = DateTime.now().year;
    final years = List.generate(30, (i) => currentYear - i);

    Widget labeled(String label, IconData icon, Widget child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: theme.colorScheme.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      );
    }

    Widget buildFilterDropdown<T>({
      required String title,
      required IconData icon,
      required T? value,
      required List<DropdownMenuItem<T>> items,
      required ValueChanged<T?> onChanged,
      String label = 'Any',
      String? tooltip,
      bool enabled = true,
    }) {
      return labeled(
        title,
        icon,
        FilterDropdown<T>(
          label: label,
          value: value,
          tooltip: tooltip,
          items: items,
          onChanged: onChanged,
          enabled: enabled,
        ),
      );
    }

    final dropdowns = <Widget>[
      labeled(
        'Genre',
        Icons.category_rounded,
        MultiSelectDropdown<AnilistGenre>(
          label: 'Any',
          selectedValues: genres,
          options: AnilistGenre.values
              .where((g) => g != AnilistGenre.hentai)
              .toList(),
          optionLabel: (g) => g.toGraphql(),
          onChanged: onGenresChanged,
          enabled: !isListFilterActive,
        ),
      ),
      buildFilterDropdown<int>(
        title: 'Year',
        icon: Icons.calendar_month_rounded,
        value: year,
        items: years
            .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
            .toList(),
        onChanged: onYearChanged,
        enabled: !isListFilterActive,
      ),
      buildFilterDropdown<AnilistSeason>(
        title: 'Season',
        icon: Icons.light_mode_rounded,
        value: season,
        items: AnilistSeason.values
            .map(
              (s) =>
                  DropdownMenuItem(value: s, child: Text(s.toDisplayLabel())),
            )
            .toList(),
        onChanged: onSeasonChanged,
        enabled: !isListFilterActive,
      ),
      labeled(
        'Format',
        Icons.tv_rounded,
        MultiSelectDropdown<AnilistFormat>(
          label: 'Any',
          selectedValues: formats,
          options: AnilistFormat.values,
          optionLabel: (f) => f.toDisplayLabel(),
          onChanged: onFormatsChanged,
          enabled: !isListFilterActive,
        ),
      ),
      labeled(
        'Status',
        Icons.sensors_rounded,
        MultiSelectDropdown<AnilistAiringStatus>(
          label: 'Any',
          selectedValues: airingStatuses,
          options: AnilistAiringStatus.values,
          optionLabel: (s) => s.toDisplayLabel(),
          onChanged: onAiringStatusesChanged,
          enabled: !isListFilterActive,
        ),
      ),
      if (isAuthenticated)
        buildFilterDropdown<AnilistMediaListStatus>(
          title: 'My List',
          icon: Icons.bookmark_rounded,
          value: listStatus,
          tooltip: 'Only show anime in your AniList library',
          items: AnilistMediaListStatus.values
              .map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(status.toDisplayLabel()),
                ),
              )
              .toList(),
          onChanged: onListStatusChanged,
        ),
    ];

    final activeChips = <Widget>[];
    for (final genre in genres) {
      activeChips.add(
        ActiveFilterChip(
          label: genre.toGraphql(),
          onRemove: () =>
              onGenresChanged(genres.where((g) => g != genre).toList()),
        ),
      );
    }
    if (year != null) {
      activeChips.add(
        ActiveFilterChip(
          label: year.toString(),
          onRemove: () => onYearChanged(null),
        ),
      );
    }
    if (season != null) {
      activeChips.add(
        ActiveFilterChip(
          label: season!.toDisplayLabel(),
          onRemove: () => onSeasonChanged(null),
        ),
      );
    }
    for (final format in formats) {
      activeChips.add(
        ActiveFilterChip(
          label: format.toDisplayLabel(),
          onRemove: () =>
              onFormatsChanged(formats.where((f) => f != format).toList()),
        ),
      );
    }
    for (final status in airingStatuses) {
      activeChips.add(
        ActiveFilterChip(
          label: status.toDisplayLabel(),
          onRemove: () => onAiringStatusesChanged(
            airingStatuses.where((s) => s != status).toList(),
          ),
        ),
      );
    }
    if (listStatus != null) {
      activeChips.add(
        ActiveFilterChip(
          label: listStatus!.toDisplayLabel(),
          onRemove: () => onListStatusChanged(null),
        ),
      );
    }

    final activeCount = _activeFilterCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - 2 * horizontalPadding;
        final int columns = width >= 960 ? 6 : (width >= 600 ? 3 : 2);

        final filterRows = <Widget>[];
        for (int i = 0; i < dropdowns.length; i += columns) {
          final rowItems = dropdowns.sublist(
            i,
            min(i + columns, dropdowns.length),
          );
          filterRows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int j = 0; j < rowItems.length; j++) ...[
                  if (j > 0) const SizedBox(width: 10),
                  Expanded(child: rowItems[j]),
                ],
                for (int k = rowItems.length; k < columns; k++) ...[
                  const SizedBox(width: 10),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ],
            ),
          );
          if (i + columns < dropdowns.length) {
            filterRows.add(const SizedBox(height: 10));
          }
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: isDark ? 0.4 : 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.18,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              onChanged: onSearchChanged,
                              enabled: !isListFilterActive,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Search anime...',
                                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                              ),
                            ),
                          ),
                          if (searchController.text.isNotEmpty)
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: onClearSearch,
                                child: Icon(
                                  Icons.clear_rounded,
                                  size: 18,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: filtersExpanded ? 'Hide filters' : 'Show filters',
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              onFiltersExpandedChanged(!filtersExpanded),
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: filtersExpanded
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.15,
                                    )
                                  : theme.colorScheme.surfaceContainerHighest
                                        .withValues(alpha: isDark ? 0.4 : 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: filtersExpanded
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.5,
                                      )
                                    : theme.colorScheme.outline.withValues(
                                        alpha: 0.18,
                                      ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  size: 18,
                                  color: filtersExpanded
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                ),
                                if (activeCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$activeCount',
                                      style: TextStyle(
                                        color: theme.colorScheme.onPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.vertical,
                      axisAlignment: -1.0,
                      child: child,
                    ),
                  );
                },
                child: filtersExpanded
                    ? KeyedSubtree(
                        key: const ValueKey('expanded_filters_panel'),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: filterRows,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('collapsed_filters_panel'),
                      ),
              ),
              ActiveFilterChips(
                chips: activeChips,
                onClearAll: _clearAllFilters,
              ),
            ],
          ),
        );
      },
    );
  }
}
