import 'dart:async';

import 'package:flutter/material.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/shared/shared.dart';
import 'package:senpwai/ui/core/pagination.dart';
import 'package:senpwai/ui/core/responsive.dart';
import 'package:senpwai/ui/components/anime_card/anime_compact_card.dart';
import 'package:senpwai/ui/components/anime_card/anime_detailed_card.dart';
import 'package:senpwai/ui/components/anime_card/card_switcher.dart';
import 'package:senpwai/ui/components/anime_card/anime_card_grid.dart';
import 'package:senpwai/ui/components/filter_dropdown.dart';

class SearchPage extends StatefulWidget {
  final AnilistAuthenticatedClient authClient;
  final AnilistUnauthenticatedClient unauthClient;
  final bool isAuthenticated;

  const SearchPage({
    super.key,
    required this.authClient,
    required this.unauthClient,
    required this.isAuthenticated,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with PaginatedScrollMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  List<AnilistGenre> _genres = [];
  bool _filtersExpanded = false;
  AnilistAiringStatus? _airingStatus;
  AnilistMediaListStatus? _listStatus;
  AnilistSeason? _season;
  int? _year;
  AnilistFormat? _format;
  AnilistMediaSort? _sort;
  bool _sortDescending = true;
  CardViewMode _viewMode = CardViewMode.grid;

  List<AnilistAnimeBase> _results = [];
  Pagination<List<AnilistAnimeBase>>? _pagination;
  bool _loading = false;
  bool _loadingMore = false;

  @override
  ScrollController get paginationScrollController => _scrollController;

  @override
  bool get isLoadingMore => _loadingMore;

  @override
  bool get hasNextPage => _pagination?.fetchNextPage != null;

  @override
  void initState() {
    super.initState();
    initPaginatedScroll();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    disposePaginatedScroll();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _results = [];
      _pagination = null;
    });
    try {
      final term = _searchController.text.trim();
      final genres = _genres.isEmpty ? null : _genres;

      if (widget.isAuthenticated) {
        final result = await widget.authClient.searchAnime(
          params: AuthenticatedAnimeSearchParams(
            term: term.isEmpty ? null : term,
            genres: genres,
            season: _season,
            seasonYear: _year,
            format: _format,
            airingStatus: _airingStatus,
            listStatus: _listStatus,
            sort: _sort,
            sortDescending: _sortDescending,
            onlyIncludeUserListEntry: _listStatus != null,
            perPage: 25,
          ),
        );
        if (mounted) {
          setState(() {
            _results = result.items;
            _pagination = result;
          });
        }
      } else {
        final result = await widget.unauthClient.searchAnime(
          params: AnimeSearchParams(
            term: term.isEmpty ? null : term,
            genres: genres,
            season: _season,
            seasonYear: _year,
            format: _format,
            airingStatus: _airingStatus,
            sort: _sort,
            sortDescending: _sortDescending,
            perPage: 25,
          ),
        );
        if (mounted) {
          setState(() {
            _results = result.items;
            _pagination = result;
          });
        }
      }
    } catch (_) {
      // Silently handle
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Future<void> loadNextPage() async {
    if (_pagination?.fetchNextPage == null) return;
    setState(() => _loadingMore = true);
    try {
      final next = await _pagination!.fetchNextPage!();
      if (mounted) {
        setState(() {
          _results = [..._results, ...next.items];
          _pagination = next;
        });
      }
    } catch (_) {
      // Silently handle
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = horizontalPadding(context);
    final cols = gridCrossAxisCount(context);

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Search bar + filters combined
        SliverToBoxAdapter(child: _buildSearchAndFilters(context, pad)),

        // Toolbar: sort + view toggle + result count
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 8, pad, 4),
            child: Row(
              children: [
                // Result count
                if (!_loading)
                  Text(
                    () {
                      final total = _pagination?.totalResults;
                      if (total != null) {
                        return '$total result${total == 1 ? '' : 's'}';
                      }
                      return '${_results.length} result${_results.length == 1 ? '' : 's'}';
                    }(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: isMobile(context) ? 11 : null,
                    ),
                  ),
                const Spacer(),
                // Sort dropdown
                SizedBox(
                  width: isMobile(context) ? 110 : 140,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AnilistMediaSort?>(
                      value: _sort,
                      isExpanded: true,
                      isDense: true,
                      hint: Text(
                        'Sort by',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                          fontSize: isMobile(context) ? 11 : null,
                        ),
                      ),
                      items: AnilistMediaSort.values
                          .map(
                            (s) => DropdownMenuItem<AnilistMediaSort?>(
                              value: s,
                              child: Text(
                                s.toLabel(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: isMobile(context) ? 11 : null,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() => _sort = v);
                        _onFilterChanged();
                      },
                      dropdownColor: theme.colorScheme.surfaceContainerHighest,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: isMobile(context) ? 11 : null,
                      ),
                    ),
                  ),
                ),
                // Asc/Desc toggle
                IconButton(
                  icon: Icon(
                    _sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
                    size: isMobile(context) ? 16 : 18,
                  ),
                  tooltip: _sortDescending ? 'Descending' : 'Ascending',
                  onPressed: () {
                    setState(() => _sortDescending = !_sortDescending);
                    _onFilterChanged();
                  },
                  visualDensity: VisualDensity.compact,
                ),
                SizedBox(width: isMobile(context) ? 2 : 4),
                // View mode toggle
                CardSwitcher(
                  selected: _viewMode,
                  onSwitch: (mode) => setState(() => _viewMode = mode),
                ),
              ],
            ),
          ),
        ),

        // Results
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
          sliver: SliverToBoxAdapter(
            child: _viewMode == CardViewMode.grid
                ? AnimeCardGrid(
                    anime: _results,
                    isLoading: _loading,
                    loadingMore: _loadingMore,
                    crossAxisCount: cols,
                  )
                : _viewMode == CardViewMode.compact
                ? _buildCompactList(context)
                : _buildDetailedList(context),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildDetailedList(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_results.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 8),
              Text(
                'No results found',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ..._results.map((anime) => AnimeDetailedCard(anime: anime)),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildCompactList(BuildContext context) {
    final theme = Theme.of(context);
    final cols = isMobile(context) ? 1 : 2;
    final compactRatio = compactCardAspectRatio(context);
    final spacing = gridSpacing(context);

    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_results.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 8),
              Text(
                'No results found',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: compactRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: _results.length,
          itemBuilder: (_, i) => AnimeCompactCard(anime: _results[i]),
        ),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildSearchAndFilters(BuildContext context, double pad) {
    final theme = Theme.of(context);
    final currentYear = DateTime.now().year;
    final years = List.generate(30, (i) => currentYear - i);

    // Helper: wrap a widget with a small section label above
    Widget labeled(String lbl, Widget child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lbl,
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

    final searchField = labeled(
      'Search',
      TextField(
        controller: _searchController,
        onChanged: (_) => _onFilterChanged(),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          hintText: 'Search anime...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onFilterChanged();
                  },
                )
              : null,
        ),
      ),
    );

    final dropdowns = <Widget>[
      labeled(
        'Genres',
        MultiSelectDropdown<AnilistGenre>(
          label: 'Any',
          selectedValues: _genres,
          options: AnilistGenre.values
              .where((g) => g != AnilistGenre.hentai)
              .toList(),
          optionLabel: (g) => g.toGraphql(),
          onChanged: (values) {
            setState(() => _genres = values);
            _onFilterChanged();
          },
        ),
      ),
      labeled(
        'Year',
        FilterDropdown<int>(
          label: 'Any',
          value: _year,
          items: years
              .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
              .toList(),
          onChanged: (v) {
            setState(() => _year = v);
            _onFilterChanged();
          },
        ),
      ),
      labeled(
        'Season',
        FilterDropdown<AnilistSeason>(
          label: 'Any',
          value: _season,
          items: AnilistSeason.values
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.toGraphql().toLowerCase().capitalize()),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() => _season = v);
            _onFilterChanged();
          },
        ),
      ),
      labeled(
        'Format',
        FilterDropdown<AnilistFormat>(
          label: 'Any',
          value: _format,
          items: AnilistFormat.values
              .map(
                (f) => DropdownMenuItem(
                  value: f,
                  child: Text(f.toGraphql().replaceAll('_', ' ')),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() => _format = v);
            _onFilterChanged();
          },
        ),
      ),
      labeled(
        'Status',
        FilterDropdown<AnilistAiringStatus>(
          label: 'Any',
          value: _airingStatus,
          items: AnilistAiringStatus.values
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(
                    s
                        .toGraphql()
                        .replaceAll('_', ' ')
                        .toLowerCase()
                        .capitalize(),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() => _airingStatus = v);
            _onFilterChanged();
          },
        ),
      ),
      if (widget.isAuthenticated)
        labeled(
          'My List',
          FilterDropdown<AnilistMediaListStatus>(
            label: 'Any',
            value: _listStatus,
            tooltip: 'Only show anime in your AniList library',
            items: AnilistMediaListStatus.values
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      s
                          .toGraphql()
                          .replaceAll('_', ' ')
                          .toLowerCase()
                          .capitalize(),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() => _listStatus = v);
              _onFilterChanged();
            },
          ),
        ),
    ];

    // Active filter chips (tap to remove)
    final activeChips = <Widget>[
      ..._genres.map(
        (g) => _ActiveFilterChip(
          label: g.toGraphql(),
          onRemove: () {
            setState(() => _genres = List.from(_genres)..remove(g));
            _onFilterChanged();
          },
        ),
      ),
      if (_year != null)
        _ActiveFilterChip(
          label: '$_year',
          onRemove: () {
            setState(() => _year = null);
            _onFilterChanged();
          },
        ),
      if (_season != null)
        _ActiveFilterChip(
          label: _season!.toGraphql().toLowerCase().capitalize(),
          onRemove: () {
            setState(() => _season = null);
            _onFilterChanged();
          },
        ),
      if (_format != null)
        _ActiveFilterChip(
          label: _format!.toGraphql().replaceAll('_', ' '),
          onRemove: () {
            setState(() => _format = null);
            _onFilterChanged();
          },
        ),
      if (_airingStatus != null)
        _ActiveFilterChip(
          label: _airingStatus!
              .toGraphql()
              .replaceAll('_', ' ')
              .toLowerCase()
              .capitalize(),
          onRemove: () {
            setState(() => _airingStatus = null);
            _onFilterChanged();
          },
        ),
      if (_listStatus != null)
        _ActiveFilterChip(
          label: _listStatus!
              .toGraphql()
              .replaceAll('_', ' ')
              .toLowerCase()
              .capitalize(),
          onRemove: () {
            setState(() => _listStatus = null);
            _onFilterChanged();
          },
        ),
    ];

    // Minimum width needed to show search + all dropdowns inline without scrolling
    // search(260) + gap(12) + each labeled dropdown(160 + 10 gap = 170)
    final inlineWidth = 260.0 + 12 + dropdowns.length * 170.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showInline = constraints.maxWidth >= inlineWidth;
        return Padding(
          padding: EdgeInsets.fromLTRB(pad, showInline ? 20 : 12, pad, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page title (only when everything fits inline)
              if (showInline) ...[
                Text('Search', style: theme.textTheme.displaySmall),
                const SizedBox(height: 16),
              ],
              if (!showInline) ...[
                // Narrow: search field + filter toggle button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      icon: Icon(
                        Icons.tune,
                        size: 20,
                        color: _filtersExpanded
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      style: IconButton.styleFrom(
                        side: BorderSide(
                          color: _filtersExpanded
                              ? theme.colorScheme.primary.withValues(alpha: 0.6)
                              : theme.colorScheme.outline.withValues(
                                  alpha: 0.25,
                                ),
                        ),
                        backgroundColor: _filtersExpanded
                            ? theme.colorScheme.primary.withValues(alpha: 0.06)
                            : null,
                      ),
                      tooltip: 'Filters',
                      onPressed: () =>
                          setState(() => _filtersExpanded = !_filtersExpanded),
                    ),
                  ],
                ),
                if (_filtersExpanded) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 10, children: dropdowns),
                ],
              ] else ...[
                // Wide: all fit in one row, no scrolling needed
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 260, child: searchField),
                    const SizedBox(width: 12),
                    ...dropdowns.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: d,
                      ),
                    ),
                  ],
                ),
              ],
              // Active filter chips
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
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 3, 6, 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.close,
              size: 12,
              color: theme.colorScheme.primary.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}
