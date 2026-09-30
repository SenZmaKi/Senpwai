import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/shared.dart';
import 'package:senpwai/ui/components/anime_banner_carousel.dart';
import 'package:senpwai/ui/components/anime_card/anime_card_horizontal.dart';
import 'package:senpwai/ui/components/section_header.dart';
import 'package:senpwai/ui/shared/anilist.dart';
import 'package:senpwai/ui/shared/responsive.dart';

final _log = Logger('senpwai.ui.pages.home');

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
    if (ref.read(AnilistNotifier.provider).isAuthLoading) return;
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
    } catch (error, stack) {
      _logLoadFailure('trending', error, stack);
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
    } catch (error, stack) {
      _logLoadFailure('currently watching', error, stack);
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
    } catch (error, stack) {
      _logLoadFailure('popular anime', error, stack);
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
    } catch (error, stack) {
      _logLoadFailure('genre ${section.name}', error, stack);
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
    } catch (error, stack) {
      _logLoadFailure('pagination', error, stack);
    } finally {
      if (mounted) setLoading(false);
    }
  }

  void _logLoadFailure(String section, Object error, StackTrace stack) {
    _log.warning('AniList Home section failed: $section', error, stack);
  }

  List<Widget> _buildSection({
    required String id,
    required String title,
    required IconData icon,
    required List<AnilistAnimeBase> items,
    required bool isLoading,
    required bool isLoadingMore,
    required Future<Pagination<List<AnilistAnimeBase>>> Function()? fetchNext,
    required void Function(
      List<AnilistAnimeBase>,
      Future<Pagination<List<AnilistAnimeBase>>> Function()?,
    )
    onResult,
    required void Function(bool) setLoading,
  }) {
    final pad = horizontalPadding(context);
    final viewMode = ref.watch(
      AppSettingsNotifier.provider.select(
        (settings) => settings.appearance.cardViewMode,
      ),
    );
    final homeViewMode = viewMode == CardViewMode.table
        ? CardViewMode.landscape
        : viewMode;
    return [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: pad),
        child: SectionHeader(title: title, icon: icon),
      ),
      AnimeCardHorizontal(
        key: ValueKey('home-section-$id'),
        anime: items,
        viewMode: homeViewMode,
        isLoading: isLoading,
        isLoadingMore: isLoadingMore,
        onLoadMore: fetchNext != null
            ? () => _loadMore(
                current: items,
                fetchNext: fetchNext,
                isLoading: isLoadingMore,
                onResult: onResult,
                setLoading: setLoading,
              )
            : null,
      ),
      const SizedBox(height: 20),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(AnilistNotifier.provider, (previous, next) {
      final authenticationFinished =
          previous?.isAuthLoading == true && !next.isAuthLoading;
      final authenticationChanged =
          previous?.isAuthenticated != next.isAuthenticated;
      final snapshotChanged =
          previous?.listSnapshotRevision != next.listSnapshotRevision;
      if (authenticationFinished ||
          (!next.isAuthLoading && (authenticationChanged || snapshotChanged))) {
        _load();
      }
    });
    final anilist = ref.watch(AnilistNotifier.provider);
    final children = [
      AnimeBannerCarousel(anime: _trending, isLoading: _trendingLoading),
      const SizedBox(height: 16),

      if (anilist.isAuthenticated)
        ..._buildSection(
          id: 'watching',
          title: 'Currently Watching',
          icon: Icons.play_circle_outline,
          items: _watching,
          isLoading: _watchingLoading,
          isLoadingMore: _watchingLoadingMore,
          fetchNext: _watchingFetchNext,
          onResult: (items, next) {
            _watching = items;
            _watchingFetchNext = next;
          },
          setLoading: (v) => setState(() => _watchingLoadingMore = v),
        ),

      ..._buildSection(
        id: 'trending',
        title: 'Trending This Season',
        icon: Icons.local_fire_department,
        items: _trending,
        isLoading: _trendingLoading,
        isLoadingMore: _trendingLoadingMore,
        fetchNext: _trendingFetchNext,
        onResult: (items, next) {
          _trending = items;
          _trendingFetchNext = next;
        },
        setLoading: (v) => setState(() => _trendingLoadingMore = v),
      ),

      ..._buildSection(
        id: 'popular',
        title: 'Popular Anime',
        icon: Icons.trending_up,
        items: _topRated,
        isLoading: _topRatedLoading,
        isLoadingMore: _topRatedLoadingMore,
        fetchNext: _topRatedFetchNext,
        onResult: (items, next) {
          _topRated = items;
          _topRatedFetchNext = next;
        },
        setLoading: (v) => setState(() => _topRatedLoadingMore = v),
      ),

      for (final (index, section) in _genreSections.indexed)
        ..._buildSection(
          id: 'genre-$index',
          title: section.name.isEmpty ? 'Discover' : 'Explore: ${section.name}',
          icon: Icons.explore_outlined,
          items: section.items,
          isLoading: section.loading,
          isLoadingMore: section.loadingMore,
          fetchNext: section.fetchNext,
          onResult: (items, next) {
            section.items = items;
            section.fetchNext = next;
          },
          setLoading: (v) => setState(() => section.loadingMore = v),
        ),

      const SizedBox(height: 32),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [SliverList(delegate: SliverChildListDelegate(children))],
      ),
    );
  }
}
