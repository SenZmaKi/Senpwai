import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/shared/shared.dart';
import 'package:senpwai/ui/components/anime_card/card_switcher.dart';
import 'package:senpwai/ui/shared/anilist.dart';
import 'package:senpwai/ui/shared/pagination.dart';
import 'package:senpwai/ui/shared/responsive.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/pages/search_page/search_filters_section.dart';
import 'package:senpwai/ui/pages/search_page/search_results_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with PaginatedScrollMixin, SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  late final AnimationController _sortIconController;

  List<AnilistGenre> _genres = [];
  bool _filtersExpanded = false;
  List<AnilistAiringStatus> _airingStatuses = [];
  AnilistMediaListStatus? _listStatus;
  AnilistSeason? _season;
  int? _year;
  List<AnilistFormat> _formats = [];
  AnilistMediaSort? _sort = AnilistMediaSort.trending;
  bool _sortDescending = true;
  CardViewMode _viewMode = CardViewMode.poster;

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
    _sortIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    initPaginatedScroll();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _sortIconController.dispose();
    disposePaginatedScroll();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  void _applyFilter(VoidCallback updateState) {
    setState(updateState);
    _onFilterChanged();
  }

  void _onSearchTermChanged(String _) {
    setState(() {});
    _onFilterChanged();
  }

  void _clearSearchTerm() {
    setState(() => _searchController.clear());
    _onFilterChanged();
  }

  void _showSearchError(Object error, StackTrace stack) {
    if (!mounted) return;
    final String title;
    final String description;

    if (error is AnilistAuthRequiredException) {
      title = 'Authentication required';
      description = 'Sign in to use this filter.';
    } else if (error is AnilistInvalidTokenException) {
      title = 'Session expired';
      description = 'Your AniList session has expired. Please sign in again.';
    } else if (error is AnilistEmptyResponseException) {
      title = 'Empty response';
      description = 'AniList returned an empty response. Try again.';
    } else if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 429) {
        title = 'Rate limited';
        description = 'Too many requests. Please wait a moment.';
      } else if (statusCode != null && statusCode >= 500) {
        title = 'AniList server error';
        description = 'AniList returned $statusCode. Try again later.';
      } else if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        title = 'Connection timeout';
        description = 'Request timed out. Check your connection.';
      } else if (error.type == DioExceptionType.connectionError) {
        title = 'No connection';
        description = 'Could not reach AniList. Check your internet.';
      } else {
        title = 'Search error';
        description = error.message ?? error.toString();
      }
    } else if (error is AnilistException) {
      title = 'Search error';
      description = error.message;
    } else {
      title = 'Search error';
      description = error.toString();
    }

    AppToast.showError(
      context,
      title: title,
      description: description,
      copyPayload: formatErrorForCopy(error, stack),
    );
  }

  Future<void> _search() async {
    final providerContainer = ProviderScope.containerOf(context, listen: false);
    final anilist = providerContainer.read(AnilistNotifier.provider);
    final anilistNotifier = providerContainer.read(
      AnilistNotifier.provider.notifier,
    );

    setState(() {
      _loading = true;
      _results = [];
      _pagination = null;
    });

    try {
      final term = _searchController.text.trim();
      final genres = _genres.isNotEmpty ? _genres : null;
      final formats = _formats.isNotEmpty ? _formats : null;
      final airingStatuses = _airingStatuses.isNotEmpty
          ? _airingStatuses
          : null;

      if (anilist.isAuthenticated && _listStatus != null) {
        final result = await anilistNotifier.authClient.listUserMediaList(
          listStatus: _listStatus!,
          perPage: 25,
        );

        if (mounted) {
          setState(() {
            _results = result.items;
            _pagination = result;
          });
        }
      } else if (anilist.isAuthenticated) {
        final result = await anilistNotifier.authClient.searchAnime(
          params: AuthenticatedAnimeSearchParams(
            term: term.isEmpty ? null : term,
            genres: genres,
            season: _season,
            seasonYear: _year,
            formats: formats,
            airingStatuses: airingStatuses,
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
      } else {
        final result = await anilistNotifier.unauthClient.searchAnime(
          params: AnimeSearchParams(
            term: term.isEmpty ? null : term,
            genres: genres,
            season: _season,
            seasonYear: _year,
            formats: formats,
            airingStatuses: airingStatuses,
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
    } catch (error, stack) {
      _showSearchError(error, stack);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
    } catch (error, stack) {
      _showSearchError(error, stack);
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final horizontalPad = horizontalPadding(context);

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: SearchFiltersSection(
            searchController: _searchController,
            filtersExpanded: _filtersExpanded,
            horizontalPadding: horizontalPad,
            genres: _genres,
            airingStatuses: _airingStatuses,
            listStatus: _listStatus,
            season: _season,
            year: _year,
            formats: _formats,
            isListFilterActive: _listStatus != null,
            onFiltersExpandedChanged: (expanded) {
              setState(() => _filtersExpanded = expanded);
            },
            onSearchChanged: _onSearchTermChanged,
            onClearSearch: _clearSearchTerm,
            onGenresChanged: (value) => _applyFilter(() => _genres = value),
            onYearChanged: (value) => _applyFilter(() => _year = value),
            onSeasonChanged: (value) => _applyFilter(() => _season = value),
            onFormatsChanged: (value) => _applyFilter(() => _formats = value),
            onAiringStatusesChanged: (value) =>
                _applyFilter(() => _airingStatuses = value),
            onListStatusChanged: (value) => _applyFilter(() {
              _listStatus = value;
              if (value != null) {
                _searchController.clear();
                _genres = [];
                _airingStatuses = [];
                _season = null;
                _year = null;
                _formats = [];
                _sort = AnilistMediaSort.trending;
                _sortDescending = true;
              }
            }),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontalPad, 8, horizontalPad, 4),
            child: Row(
              children: [
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Opacity(
                    opacity: _listStatus != null ? 0.5 : 1.0,
                    child: IgnorePointer(
                      ignoring: _listStatus != null,
                      child: SizedBox(
                        width: isMobile(context) ? 100 : 120,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<AnilistMediaSort?>(
                            value: _sort,
                            isExpanded: true,
                            isDense: true,
                            icon: Icon(
                              Icons.unfold_more,
                              size: 16,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
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
                                  (sort) => DropdownMenuItem<AnilistMediaSort?>(
                                    value: sort,
                                    child: Text(
                                      sort.toLabel(),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: isMobile(context)
                                                ? 11
                                                : null,
                                          ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              _applyFilter(() => _sort = value);
                            },
                            dropdownColor:
                                theme.colorScheme.surfaceContainerHighest,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: isMobile(context) ? 11 : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Opacity(
                  opacity: _listStatus != null ? 0.5 : 1.0,
                  child: IgnorePointer(
                    ignoring: _listStatus != null,
                    child: IconButton(
                      icon: AnimatedBuilder(
                        animation: _sortIconController,
                        builder: (context, child) => Transform.rotate(
                          angle: _sortIconController.value * 3.14159,
                          child: child,
                        ),
                        child: Icon(
                          _sortDescending
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          size: isMobile(context) ? 16 : 18,
                        ),
                      ),
                      tooltip: _sortDescending ? 'Descending' : 'Ascending',
                      onPressed: () {
                        _sortIconController.forward(from: 0);
                        _applyFilter(() => _sortDescending = !_sortDescending);
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                SizedBox(width: isMobile(context) ? 2 : 4),
                CardSwitcher(
                  selected: _viewMode,
                  onSwitch: (mode) => setState(() => _viewMode = mode),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontalPad, 8, horizontalPad, 0),
          sliver: SliverToBoxAdapter(
            child: SearchResultsSection(
              results: _results,
              loading: _loading,
              loadingMore: _loadingMore,
              viewMode: _viewMode,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}
