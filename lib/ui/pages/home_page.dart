import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/shared/shared.dart';
import 'package:senpwai/ui/components/anime_card/anime_poster_horizontal.dart';
import 'package:senpwai/ui/components/section_header.dart';
import 'package:senpwai/ui/shared/anilist.dart';
import 'package:senpwai/ui/shared/responsive.dart';

Pagination<List<AnilistAnimeBase>> _castPagination<T extends AnilistAnimeBase>(
  Pagination<List<T>> p,
) {
  return Pagination<List<AnilistAnimeBase>>(
    currentPage: p.currentPage,
    totalPages: p.totalPages,
    items: p.items,
    fetchNextPage: p.fetchNextPage != null
        ? () async => _castPagination(await p.fetchNextPage!())
        : null,
    perPage: p.perPage,
    totalResults: p.totalResults,
  );
}

class HomePage extends ConsumerStatefulWidget {
  final VoidCallback onLoginTap;

  const HomePage({super.key, required this.onLoginTap});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _GenreSection {
  List<AnilistAnimeBase> items = [];
  String name = '';
  bool loading = true;
  bool loadingMore = false;
  Future<Pagination<List<AnilistAnimeBase>>> Function()? fetchNext;
}

class _HomePageState extends ConsumerState<HomePage> {
  List<AnilistAnimeBase> _trending = [];
  List<AnilistAnimeBase> _watching = [];
  List<AnilistAnimeBase> _topRated = [];
  final List<_GenreSection> _genreSections = List.generate(
    3,
    (_) => _GenreSection(),
  );

  bool _trendingLoading = true;
  bool _watchingLoading = true;
  bool _topRatedLoading = true;

  bool _trendingLoadingMore = false;
  bool _watchingLoadingMore = false;
  bool _topRatedLoadingMore = false;

  Future<Pagination<List<AnilistAnimeBase>>> Function()? _trendingFetchNext;
  Future<Pagination<List<AnilistAnimeBase>>> Function()? _watchingFetchNext;
  Future<Pagination<List<AnilistAnimeBase>>> Function()? _topRatedFetchNext;

  @override
  void initState() {
    super.initState();
    _load();
  }

  AnilistNotifier get _anilist => ref.read(AnilistNotifier.provider.notifier);
  bool get _isAuthenticated =>
      ref.read(AnilistNotifier.provider).isAuthenticated;

  Future<void> _load() async {
    _loadTrending();
    _loadTopRated();
    for (final section in _genreSections) {
      _loadGenreSection(section);
    }
    if (_isAuthenticated) {
      _loadWatching();
    } else {
      if (mounted) setState(() => _watchingLoading = false);
    }
  }

  Future<void> _loadTrending() async {
    setState(() => _trendingLoading = true);
    try {
      Pagination<List<AnilistAnimeBase>> pagination;
      if (_isAuthenticated) {
        pagination = _castPagination(
          await _anilist.authClient.trendingThisSeason(),
        );
      } else {
        pagination = _castPagination(
          await _anilist.unauthClient.trendingThisSeason(),
        );
      }
      if (mounted) {
        setState(() {
          _trending = pagination.items;
          _trendingFetchNext = pagination.fetchNextPage;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _trendingLoading = false);
    }
  }

  Future<void> _loadWatching() async {
    if (!_isAuthenticated) return;
    setState(() => _watchingLoading = true);
    try {
      final pagination = _castPagination(
        await _anilist.authClient.listUserMediaList(
          listStatus: AnilistMediaListStatus.current,
          perPage: 25,
        ),
      );
      if (mounted) {
        setState(() {
          _watching = pagination.items;
          _watchingFetchNext = pagination.fetchNextPage;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _watchingLoading = false);
    }
  }

  Future<void> _loadTopRated() async {
    setState(() => _topRatedLoading = true);
    try {
      Pagination<List<AnilistAnimeBase>> pagination;
      if (_isAuthenticated) {
        pagination = _castPagination(
          await _anilist.authClient.searchAnime(
            params: const AuthenticatedAnimeSearchParams(perPage: 15),
          ),
        );
      } else {
        pagination = _castPagination(
          await _anilist.unauthClient.searchAnime(
            params: const AnimeSearchParams(perPage: 15),
          ),
        );
      }
      if (mounted) {
        setState(() {
          _topRated = pagination.items;
          _topRatedFetchNext = pagination.fetchNextPage;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _topRatedLoading = false);
    }
  }

  Future<void> _loadGenreSection(_GenreSection section) async {
    setState(() => section.loading = true);
    final genres = AnilistGenre.values
        .where((g) => g != AnilistGenre.hentai)
        .where(
          (g) => !_genreSections.any(
            (s) => s != section && s.name == g.toGraphql(),
          ),
        )
        .toList();
    final random = genres[Random().nextInt(genres.length)];
    section.name = random.toGraphql();
    try {
      Pagination<List<AnilistAnimeBase>> pagination;
      if (_isAuthenticated) {
        pagination = _castPagination(
          await _anilist.authClient.searchAnime(
            params: AuthenticatedAnimeSearchParams(
              genres: [random],
              perPage: 15,
            ),
          ),
        );
      } else {
        pagination = _castPagination(
          await _anilist.unauthClient.searchAnime(
            params: AnimeSearchParams(genres: [random], perPage: 15),
          ),
        );
      }
      if (mounted) {
        setState(() {
          section.items = pagination.items;
          section.fetchNext = pagination.fetchNextPage;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => section.loading = false);
    }
  }

  Future<void> _loadMore({
    required List<AnilistAnimeBase> current,
    required Future<Pagination<List<AnilistAnimeBase>>> Function()? fetchNext,
    required bool isLoading,
    required void Function(
      List<AnilistAnimeBase> items,
      Future<Pagination<List<AnilistAnimeBase>>> Function()? next,
    )
    onResult,
    required void Function(bool) setLoading,
  }) async {
    if (fetchNext == null || isLoading) return;
    setLoading(true);
    try {
      final result = await fetchNext();
      if (mounted) {
        setState(
          () => onResult([...current, ...result.items], result.fetchNextPage),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(AnilistNotifier.provider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated) {
        _loadWatching();
      }
    });
    final anilist = ref.watch(AnilistNotifier.provider);
    final theme = Theme.of(context);
    final mobile = isMobile(context);
    final pad = horizontalPadding(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          if (!mobile)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
                child: Text('Home', style: theme.textTheme.displaySmall),
              ),
            ),

          // Login prompt for unauthenticated users
          // Currently Watching (authenticated only — shown first)
          if (anilist.isAuthenticated) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: const SectionHeader(
                  title: 'Currently Watching',
                  icon: Icons.play_circle_outline,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: AnimePosterHorizontal(
                anime: _watching,
                isLoading: _watchingLoading,
                isLoadingMore: _watchingLoadingMore,
                onLoadMore: _watchingFetchNext != null
                    ? () => _loadMore(
                        current: _watching,
                        fetchNext: _watchingFetchNext,
                        isLoading: _watchingLoadingMore,
                        onResult: (items, next) {
                          _watching = items;
                          _watchingFetchNext = next;
                        },
                        setLoading: (v) =>
                            setState(() => _watchingLoadingMore = v),
                      )
                    : null,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],

          // Trending Section
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: const SectionHeader(
                title: 'Trending This Season',
                icon: Icons.local_fire_department,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimePosterHorizontal(
              anime: _trending,
              isLoading: _trendingLoading,
              isLoadingMore: _trendingLoadingMore,
              onLoadMore: _trendingFetchNext != null
                  ? () => _loadMore(
                      current: _trending,
                      fetchNext: _trendingFetchNext,
                      isLoading: _trendingLoadingMore,
                      onResult: (items, next) {
                        _trending = items;
                        _trendingFetchNext = next;
                      },
                      setLoading: (v) =>
                          setState(() => _trendingLoadingMore = v),
                    )
                  : null,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Top Results
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: const SectionHeader(
                title: 'Popular Anime',
                icon: Icons.trending_up,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimePosterHorizontal(
              anime: _topRated,
              isLoading: _topRatedLoading,
              isLoadingMore: _topRatedLoadingMore,
              onLoadMore: _topRatedFetchNext != null
                  ? () => _loadMore(
                      current: _topRated,
                      fetchNext: _topRatedFetchNext,
                      isLoading: _topRatedLoadingMore,
                      onResult: (items, next) {
                        _topRated = items;
                        _topRatedFetchNext = next;
                      },
                      setLoading: (v) =>
                          setState(() => _topRatedLoadingMore = v),
                    )
                  : null,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Genre Explore Sections
          for (final section in _genreSections) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: SectionHeader(
                  title: section.name.isEmpty
                      ? 'Discover'
                      : 'Explore: ${section.name}',
                  icon: Icons.explore_outlined,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: AnimePosterHorizontal(
                anime: section.items,
                isLoading: section.loading,
                isLoadingMore: section.loadingMore,
                onLoadMore: section.fetchNext != null
                    ? () => _loadMore(
                        current: section.items,
                        fetchNext: section.fetchNext,
                        isLoading: section.loadingMore,
                        onResult: (items, next) {
                          section.items = items;
                          section.fetchNext = next;
                        },
                        setLoading: (v) =>
                            setState(() => section.loadingMore = v),
                      )
                    : null,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
