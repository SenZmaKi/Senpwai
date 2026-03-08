import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/shared/shared.dart';
import 'package:senpwai/ui/components/filter_dropdown.dart';
import 'package:senpwai/ui/shared/anilist.dart';
import 'package:senpwai/ui/shared/responsive.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(AnilistNotifier.provider).isAuthenticated;
    final theme = Theme.of(context);
    final currentYear = DateTime.now().year;
    final years = List.generate(30, (i) => currentYear - i);

    Widget labeled(String label, Widget child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      );
    }

    Widget buildFilterDropdown<T>({
      required String title,
      required T? value,
      required List<DropdownMenuItem<T>> items,
      required ValueChanged<T?> onChanged,
      String label = 'Any',
      String? tooltip,
      bool enabled = true,
    }) {
      return labeled(
        title,
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

    final searchInput = TextField(
      controller: searchController,
      onChanged: onSearchChanged,
      enabled: !isListFilterActive,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        hintText: 'Search anime...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: onClearSearch,
              )
            : null,
      ),
    );
    final searchField = isDesktop(context)
        ? labeled('Search', searchInput)
        : searchInput;

    final dropdowns = <Widget>[
      labeled(
        'Genre',
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
        value: year,
        items: years
            .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
            .toList(),
        onChanged: onYearChanged,
        enabled: !isListFilterActive,
      ),
      buildFilterDropdown<AnilistSeason>(
        title: 'Season',
        value: season,
        items: AnilistSeason.values
            .map(
              (s) => DropdownMenuItem(
                value: s,
                child: Text(s.toGraphql().toLowerCase().capitalize()),
              ),
            )
            .toList(),
        onChanged: onSeasonChanged,
        enabled: !isListFilterActive,
      ),
      labeled(
        'Format',
        MultiSelectDropdown<AnilistFormat>(
          label: 'Any',
          selectedValues: formats,
          options: AnilistFormat.values,
          optionLabel: (f) => f.toGraphql().replaceAll('_', ' '),
          onChanged: onFormatsChanged,
          enabled: !isListFilterActive,
        ),
      ),
      labeled(
        'Status',
        MultiSelectDropdown<AnilistAiringStatus>(
          label: 'Any',
          selectedValues: airingStatuses,
          options: AnilistAiringStatus.values,
          optionLabel: (s) =>
              s.toGraphql().replaceAll('_', ' ').toLowerCase().capitalize(),
          onChanged: onAiringStatusesChanged,
          enabled: !isListFilterActive,
        ),
      ),
      if (isAuthenticated)
        buildFilterDropdown<AnilistMediaListStatus>(
          title: 'My List',
          value: listStatus,
          tooltip: 'Only show anime in your AniList library',
          items: AnilistMediaListStatus.values
              .map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(
                    status
                        .toGraphql()
                        .replaceAll('_', ' ')
                        .toLowerCase()
                        .capitalize(),
                  ),
                ),
              )
              .toList(),
          onChanged: onListStatusChanged,
        ),
    ];

    final activeChips = <Widget>[];

    for (final genre in genres) {
      activeChips.add(
        _ActiveFilterChip(
          label: genre.toGraphql(),
          onRemove: () =>
              onGenresChanged(genres.where((g) => g != genre).toList()),
        ),
      );
    }
    if (year != null) {
      activeChips.add(
        _ActiveFilterChip(
          label: year.toString(),
          onRemove: () => onYearChanged(null),
        ),
      );
    }
    if (season != null) {
      activeChips.add(
        _ActiveFilterChip(
          label: season!.toGraphql().toLowerCase().capitalize(),
          onRemove: () => onSeasonChanged(null),
        ),
      );
    }
    for (final format in formats) {
      activeChips.add(
        _ActiveFilterChip(
          label: format.toGraphql().replaceAll('_', ' '),
          onRemove: () =>
              onFormatsChanged(formats.where((f) => f != format).toList()),
        ),
      );
    }
    for (final status in airingStatuses) {
      activeChips.add(
        _ActiveFilterChip(
          label: status
              .toGraphql()
              .replaceAll('_', ' ')
              .toLowerCase()
              .capitalize(),
          onRemove: () => onAiringStatusesChanged(
            airingStatuses.where((s) => s != status).toList(),
          ),
        ),
      );
    }
    if (listStatus != null) {
      activeChips.add(
        _ActiveFilterChip(
          label: listStatus!
              .toGraphql()
              .replaceAll('_', ' ')
              .toLowerCase()
              .capitalize(),
          onRemove: () => onListStatusChanged(null),
        ),
      );
    }

    final inlineWidth = 260.0 + 12 + dropdowns.length * 170.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showInline = constraints.maxWidth >= inlineWidth;
        final maxContentWidth = showInline
            ? inlineWidth + 24
            : (constraints.maxWidth > 920 ? 920.0 : constraints.maxWidth);

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            showInline ? 20 : 12,
            horizontalPadding,
            0,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showInline) const SizedBox(height: 20),
                  if (!showInline) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          icon: Icon(
                            Icons.tune,
                            size: 20,
                            color: filtersExpanded
                                ? theme.colorScheme.primary
                                : null,
                          ),
                          style: IconButton.styleFrom(
                            side: BorderSide(
                              color: filtersExpanded
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.6,
                                    )
                                  : theme.colorScheme.outline.withValues(
                                      alpha: 0.25,
                                    ),
                            ),
                            backgroundColor: filtersExpanded
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.06,
                                  )
                                : null,
                          ),
                          tooltip: 'Filters',
                          onPressed: () =>
                              onFiltersExpandedChanged(!filtersExpanded),
                        ),
                      ],
                    ),
                    if (filtersExpanded) ...[
                      const SizedBox(height: 10),
                      Builder(
                        builder: (context) {
                          final colWidth =
                              (constraints.maxWidth -
                                  2 * horizontalPadding -
                                  10) /
                              2;
                          final rows = <Widget>[];
                          for (int i = 0; i < dropdowns.length; i += 2) {
                            rows.add(
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: colWidth,
                                    child: dropdowns[i],
                                  ),
                                  const SizedBox(width: 10),
                                  if (i + 1 < dropdowns.length)
                                    SizedBox(
                                      width: colWidth,
                                      child: dropdowns[i + 1],
                                    ),
                                ],
                              ),
                            );
                            if (i + 2 < dropdowns.length)
                              rows.add(const SizedBox(height: 10));
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: rows,
                          );
                        },
                      ),
                    ],
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(width: 260, child: searchField),
                        const SizedBox(width: 12),
                        ...dropdowns.map(
                          (dropdown) => Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: SizedBox(width: 160, child: dropdown),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (activeChips.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.label_outline, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: activeChips,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveFilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      onPressed: onRemove,
      label: Text(
        label,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      avatar: Icon(
        Icons.close,
        size: 12,
        color: theme.colorScheme.primary.withValues(alpha: 0.8),
      ),
      side: BorderSide(
        color: theme.colorScheme.primary.withValues(alpha: 0.4),
        width: 0.8,
      ),
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
