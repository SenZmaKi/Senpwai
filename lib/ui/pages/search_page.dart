import 'dart:async';

import 'package:flutter/material.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/shared/shared.dart';
import 'package:senpwai/ui/core/pagination.dart';
import 'package:senpwai/ui/core/responsive.dart';
import 'package:senpwai/ui/components/anime_grid.dart';
import 'package:senpwai/ui/components/filter_dropdown.dart';

enum CardViewMode { grid, compact, detailed }

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

  AnilistGenre? _genre;
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
  bool _filtersExpanded = true;

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
      final genres = _genre != null ? [_genre!] : null;

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
    final mobile = isMobile(context);
    final desktop = isDesktop(context);
    final pad = horizontalPadding(context);
    final cols = gridCrossAxisCount(context);

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Search bar
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, mobile ? 12 : 16, pad, 0),
            child: Row(
              children: [
                if (!mobile)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text('Search', style: theme.textTheme.displaySmall),
                  ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _onFilterChanged(),
                    decoration: InputDecoration(
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
                ),
                if (mobile) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      _filtersExpanded
                          ? Icons.filter_list_off
                          : Icons.filter_list,
                    ),
                    onPressed: () =>
                        setState(() => _filtersExpanded = !_filtersExpanded),
                    tooltip: 'Toggle filters',
                  ),
                ],
              ],
            ),
          ),
        ),

        // Filters
        SliverToBoxAdapter(
          child: AnimatedCrossFade(
            firstChild: _buildFilters(context, mobile, desktop, pad),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _filtersExpanded || !mobile
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
        ),

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
                    ),
                  ),
                const Spacer(),
                // Sort dropdown
                SizedBox(
                  width: 140,
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
                        ),
                      ),
                      items: AnilistMediaSort.values
                          .map(
                            (s) => DropdownMenuItem<AnilistMediaSort?>(
                              value: s,
                              child: Text(
                                s.toLabel(),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() => _sort = v);
                        _onFilterChanged();
                      },
                      dropdownColor: theme.colorScheme.surfaceContainerHighest,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
                // Asc/Desc toggle
                IconButton(
                  icon: Icon(
                    _sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 18,
                  ),
                  tooltip: _sortDescending ? 'Descending' : 'Ascending',
                  onPressed: () {
                    setState(() => _sortDescending = !_sortDescending);
                    _onFilterChanged();
                  },
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                // View mode toggle
                SegmentedButton<CardViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: CardViewMode.grid,
                      icon: Icon(Icons.grid_view, size: 18),
                    ),
                    ButtonSegment(
                      value: CardViewMode.compact,
                      icon: Icon(Icons.view_agenda_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: CardViewMode.detailed,
                      icon: Icon(Icons.view_list, size: 18),
                    ),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (s) =>
                      setState(() => _viewMode = s.first),
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
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
                ? AnimeGrid(
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
        ..._results.map((anime) => _DetailedAnimeCard(anime: anime)),
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
        ..._results.map((anime) => _CompactAnimeCard(anime: anime)),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildFilters(
    BuildContext context,
    bool mobile,
    bool desktop,
    double pad,
  ) {
    final theme = Theme.of(context);
    final currentYear = DateTime.now().year;
    final years = List.generate(30, (i) => currentYear - i);

    final filterWidgets = <Widget>[
      FilterDropdown<AnilistGenre>(
        label: 'Genre',
        value: _genre,
        items: AnilistGenre.values
            .where((g) => g != AnilistGenre.hentai)
            .map((g) => DropdownMenuItem(value: g, child: Text(g.toGraphql())))
            .toList(),
        onChanged: (v) {
          setState(() => _genre = v);
          _onFilterChanged();
        },
      ),
      FilterDropdown<AnilistAiringStatus>(
        label: 'Status',
        value: _airingStatus,
        items: AnilistAiringStatus.values
            .map(
              (s) => DropdownMenuItem(
                value: s,
                child: Text(
                  s.toGraphql().replaceAll('_', ' ').toLowerCase().capitalize(),
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          setState(() => _airingStatus = v);
          _onFilterChanged();
        },
      ),
      FilterDropdown<AnilistFormat>(
        label: 'Format',
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
      FilterDropdown<AnilistSeason>(
        label: 'Season',
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
      FilterDropdown<int>(
        label: 'Year',
        value: _year,
        items: years
            .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
            .toList(),
        onChanged: (v) {
          setState(() => _year = v);
          _onFilterChanged();
        },
      ),
      if (widget.isAuthenticated)
        FilterDropdown<AnilistMediaListStatus>(
          label: 'My List',
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
    ];

    final hasActiveFilter =
        _genre != null ||
        _airingStatus != null ||
        _format != null ||
        _season != null ||
        _year != null ||
        _listStatus != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
      child: Column(
        crossAxisAlignment: desktop
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: desktop ? WrapAlignment.center : WrapAlignment.start,
            children: filterWidgets,
          ),
          if (hasActiveFilter)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _genre = null;
                    _airingStatus = null;
                    _format = null;
                    _season = null;
                    _year = null;
                    _listStatus = null;
                  });
                  _onFilterChanged();
                },
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear filters'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  textStyle: theme.textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Detailed Card View ─────────────────────────────────

class _DetailedAnimeCard extends StatelessWidget {
  final AnilistAnimeBase anime;

  const _DetailedAnimeCard({required this.anime});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = anime.coverImage?.large ?? anime.coverImage?.medium;
    final title =
        anime.title.english ?? anime.title.romaji ?? anime.title.native ?? '?';
    final score = anime.averageScore;
    final desc = anime.description;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {},
          child: SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover
                if (imageUrl != null)
                  AspectRatio(
                    aspectRatio: 0.7,
                    child: Image.network(imageUrl, fit: BoxFit.cover),
                  )
                else
                  SizedBox(
                    width: 84,
                    child: Center(
                      child: Icon(
                        Icons.movie_outlined,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.2,
                        ),
                      ),
                    ),
                  ),
                // Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (score != null) ...[
                              Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${score.round()}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (anime.format != null)
                              Text(
                                anime.format!.toGraphql().replaceAll('_', ' '),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                  fontSize: 11,
                                ),
                              ),
                            if (anime.episodes != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${anime.episodes} eps',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (anime.genres.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            anime.genres.take(4).join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 10,
                            ),
                          ),
                        ],
                        if (desc != null) ...[
                          const SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              desc.replaceAll(RegExp(r'<[^>]*>'), ''),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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

// ── Compact Card View ──────────────────────────────────

class _CompactAnimeCard extends StatelessWidget {
  final AnilistAnimeBase anime;

  const _CompactAnimeCard({required this.anime});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = anime.coverImage?.medium ?? anime.coverImage?.large;
    final title =
        anime.title.english ?? anime.title.romaji ?? anime.title.native ?? '?';
    final score = anime.averageScore;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {},
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                // Small cover thumbnail
                if (imageUrl != null)
                  SizedBox(
                    width: 45,
                    child: Image.network(imageUrl, fit: BoxFit.cover),
                  )
                else
                  SizedBox(
                    width: 45,
                    child: Center(
                      child: Icon(
                        Icons.movie_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.2,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                // Title
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Metadata chips
                if (anime.format != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      anime.format!.toGraphql().replaceAll('_', ' '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                        fontSize: 10,
                      ),
                    ),
                  ),
                if (anime.episodes != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      '${anime.episodes} eps',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                        fontSize: 10,
                      ),
                    ),
                  ),
                // Score
                if (score != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${score.round()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
