import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/ui/shared/components/anime_card/anime_card_horizontal.dart';
import 'package:senpwai/ui/shared/components/section_header.dart';
import 'package:senpwai/ui/shared/components/user_avatar_button.dart';
import 'package:senpwai/ui/shared/anilist.dart';
import 'package:senpwai/ui/shared/responsive.dart';

class HomePage extends ConsumerStatefulWidget {
  final VoidCallback onLoginTap;

  const HomePage({super.key, required this.onLoginTap});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  List<AnilistAnimeBase> _trending = [];
  List<AnilistAnimeBase> _watching = [];
  List<AnilistAnimeBase> _topRated = [];
  List<AnilistAnimeBase> _randomGenre = [];
  String _randomGenreName = '';

  bool _trendingLoading = true;
  bool _watchingLoading = true;
  bool _topRatedLoading = true;
  bool _randomGenreLoading = true;

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
    _loadRandomGenre();
    if (_isAuthenticated) {
      _loadWatching();
    } else {
      if (mounted) setState(() => _watchingLoading = false);
    }
  }

  Future<void> _loadTrending() async {
    setState(() => _trendingLoading = true);
    try {
      if (_isAuthenticated) {
        final result = await _anilist.authClient.trendingThisSeason();
        if (mounted) setState(() => _trending = result.items);
      } else {
        final result = await _anilist.unauthClient.trendingThisSeason();
        if (mounted) setState(() => _trending = result.items);
      }
    } catch (_) {
      // Silently handle
    } finally {
      if (mounted) setState(() => _trendingLoading = false);
    }
  }

  Future<void> _loadWatching() async {
    if (!_isAuthenticated) return;
    setState(() => _watchingLoading = true);
    try {
      final result = await _anilist.authClient.searchAnime(
        params: const AuthenticatedAnimeSearchParams(
          listStatus: AnilistMediaListStatus.current,
          onlyIncludeUserListEntry: true,
          perPage: 25,
        ),
      );
      if (mounted) setState(() => _watching = result.items);
    } catch (_) {
      // Silently handle
    } finally {
      if (mounted) setState(() => _watchingLoading = false);
    }
  }

  Future<void> _loadTopRated() async {
    setState(() => _topRatedLoading = true);
    try {
      if (_isAuthenticated) {
        final result = await _anilist.authClient.searchAnime(
          params: const AuthenticatedAnimeSearchParams(perPage: 15),
        );
        if (mounted) setState(() => _topRated = result.items);
      } else {
        final result = await _anilist.unauthClient.searchAnime(
          params: const AnimeSearchParams(perPage: 15),
        );
        if (mounted) setState(() => _topRated = result.items);
      }
    } catch (_) {
      // Silently handle
    } finally {
      if (mounted) setState(() => _topRatedLoading = false);
    }
  }

  Future<void> _loadRandomGenre() async {
    setState(() => _randomGenreLoading = true);
    final genres = AnilistGenre.values
        .where((g) => g != AnilistGenre.hentai)
        .toList();
    final random = genres[Random().nextInt(genres.length)];
    _randomGenreName = random.toGraphql();
    try {
      if (_isAuthenticated) {
        final result = await _anilist.authClient.searchAnime(
          params: AuthenticatedAnimeSearchParams(genres: [random], perPage: 15),
        );
        if (mounted) setState(() => _randomGenre = result.items);
      } else {
        final result = await _anilist.unauthClient.searchAnime(
          params: AnimeSearchParams(genres: [random], perPage: 15),
        );
        if (mounted) setState(() => _randomGenre = result.items);
      }
    } catch (_) {
      // Silently handle
    } finally {
      if (mounted) setState(() => _randomGenreLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final anilist = ref.watch(AnilistNotifier.provider);
    final theme = Theme.of(context);
    final mobile = isMobile(context);
    final pad = horizontalPadding(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          if (mobile)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
                child: Row(
                  children: [
                    UserAvatarButton(
                      viewer: anilist.viewer,
                      isLoading: anilist.isAuthLoading,
                      onTap: widget.onLoginTap,
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),

          if (!mobile)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
                child: Text('Home', style: theme.textTheme.displaySmall),
              ),
            ),

          // Login prompt for unauthenticated users
          if (!anilist.isAuthenticated)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 8, pad, 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ),
            ),

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
            child: AnimeCardHorizontal(
              anime: _trending,
              isLoading: _trendingLoading,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Currently Watching (authenticated only)
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
              child: AnimeCardHorizontal(
                anime: _watching,
                isLoading: _watchingLoading,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],

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
            child: AnimeCardHorizontal(
              anime: _topRated,
              isLoading: _topRatedLoading,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Random Genre
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: SectionHeader(
                title: _randomGenreName.isEmpty
                    ? 'Discover'
                    : 'Explore: $_randomGenreName',
                icon: Icons.explore_outlined,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimeCardHorizontal(
              anime: _randomGenre,
              isLoading: _randomGenreLoading,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
