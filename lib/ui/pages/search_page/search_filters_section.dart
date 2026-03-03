import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/shared/shared.dart';
import 'package:senpwai/ui/components/filter_dropdown.dart';
import 'package:senpwai/ui/core/anilist_state.dart';

class SearchFiltersSection extends ConsumerWidget {
  final TextEditingController searchController;
  final bool filtersExpanded;
  final double horizontalPadding;
  final AnilistGenre? genre;
  final AnilistAiringStatus? airingStatus;
  final AnilistMediaListStatus? listStatus;
  final AnilistSeason? season;
  final int? year;
  final AnilistFormat? format;
  final ValueChanged<bool> onFiltersExpandedChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<AnilistGenre?> onGenreChanged;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<AnilistSeason?> onSeasonChanged;
  final ValueChanged<AnilistFormat?> onFormatChanged;
  final ValueChanged<AnilistAiringStatus?> onAiringStatusChanged;
  final ValueChanged<AnilistMediaListStatus?> onListStatusChanged;

  const SearchFiltersSection({
    super.key,
    required this.searchController,
    required this.filtersExpanded,
    required this.horizontalPadding,
    required this.genre,
    required this.airingStatus,
    required this.listStatus,
    required this.season,
    required this.year,
    required this.format,
    required this.onFiltersExpandedChanged,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onGenreChanged,
    required this.onYearChanged,
    required this.onSeasonChanged,
    required this.onFormatChanged,
    required this.onAiringStatusChanged,
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
    }) {
      return labeled(
        title,
        FilterDropdown<T>(
          label: label,
          value: value,
          tooltip: tooltip,
          items: items,
          onChanged: onChanged,
        ),
      );
    }

    final searchField = labeled(
      'Search',
      TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          hintText: 'Search anime...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClearSearch,
                )
              : null,
        ),
      ),
    );

    final dropdowns = <Widget>[
      buildFilterDropdown<AnilistGenre>(
        title: 'Genre',
        value: genre,
        items: AnilistGenre.values
            .where((g) => g != AnilistGenre.hentai)
            .map((g) => DropdownMenuItem(value: g, child: Text(g.toGraphql())))
            .toList(),
        onChanged: onGenreChanged,
      ),
      buildFilterDropdown<int>(
        title: 'Year',
        value: year,
        items: years
            .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
            .toList(),
        onChanged: onYearChanged,
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
      ),
      buildFilterDropdown<AnilistFormat>(
        title: 'Format',
        value: format,
        items: AnilistFormat.values
            .map(
              (f) => DropdownMenuItem(
                value: f,
                child: Text(f.toGraphql().replaceAll('_', ' ')),
              ),
            )
            .toList(),
        onChanged: onFormatChanged,
      ),
      buildFilterDropdown<AnilistAiringStatus>(
        title: 'Status',
        value: airingStatus,
        items: AnilistAiringStatus.values
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
        onChanged: onAiringStatusChanged,
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

    void addActiveChip({
      required bool enabled,
      required String label,
      required VoidCallback onRemove,
    }) {
      if (!enabled) return;
      activeChips.add(_ActiveFilterChip(label: label, onRemove: onRemove));
    }

    addActiveChip(
      enabled: genre != null,
      label: genre?.toGraphql() ?? '',
      onRemove: () => onGenreChanged(null),
    );
    addActiveChip(
      enabled: year != null,
      label: year?.toString() ?? '',
      onRemove: () => onYearChanged(null),
    );
    addActiveChip(
      enabled: season != null,
      label: season?.toGraphql().toLowerCase().capitalize() ?? '',
      onRemove: () => onSeasonChanged(null),
    );
    addActiveChip(
      enabled: format != null,
      label: format?.toGraphql().replaceAll('_', ' ') ?? '',
      onRemove: () => onFormatChanged(null),
    );
    addActiveChip(
      enabled: airingStatus != null,
      label:
          airingStatus
              ?.toGraphql()
              .replaceAll('_', ' ')
              .toLowerCase()
              .capitalize() ??
          '',
      onRemove: () => onAiringStatusChanged(null),
    );
    addActiveChip(
      enabled: listStatus != null,
      label:
          listStatus
              ?.toGraphql()
              .replaceAll('_', ' ')
              .toLowerCase()
              .capitalize() ??
          '',
      onRemove: () => onListStatusChanged(null),
    );

    final inlineWidth = 260.0 + 12 + dropdowns.length * 170.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showInline = constraints.maxWidth >= inlineWidth;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            showInline ? 20 : 12,
            horizontalPadding,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showInline) ...[
                Text('Search', style: theme.textTheme.displaySmall),
                const SizedBox(height: 16),
              ],
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
                              ? theme.colorScheme.primary.withValues(alpha: 0.6)
                              : theme.colorScheme.outline.withValues(
                                  alpha: 0.25,
                                ),
                        ),
                        backgroundColor: filtersExpanded
                            ? theme.colorScheme.primary.withValues(alpha: 0.06)
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
                  Wrap(spacing: 10, runSpacing: 10, children: dropdowns),
                ],
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 260, child: searchField),
                    const SizedBox(width: 12),
                    ...dropdowns.map(
                      (dropdown) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: dropdown,
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
