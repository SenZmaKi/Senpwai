import 'dart:math';

import 'package:flutter/material.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/ui/core/responsive.dart';
import 'package:senpwai/ui/components/anime_horizontal_list.dart';
import 'package:senpwai/ui/components/section_header.dart';
import 'package:senpwai/ui/components/user_avatar_button.dart';

class HomePage extends StatefulWidget {
  final AnilistAuthenticatedClient authClient;
  final AnilistUnauthenticatedClient unauthClient;
  final bool isAuthenticated;
  final String? avatarUrl;
  final String? userName;
  final bool isAuthLoading;
  final VoidCallback onLoginTap;

  const HomePage({
    super.key,
    required this.authClient,
    required this.unauthClient,
    required this.isAuthenticated,
    this.avatarUrl,
    this.userName,
    this.isAuthLoading = false,
    required this.onLoginTap,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAuthenticated != widget.isAuthenticated) {
      _load();
    }
  }

  Future<void> _load() async {
    _loadTrending();
    _loadTopRated();
    _loadRandomGenre();
    if (widget.isAuthenticated) {
      _loadWatching();
    } else {
      if (mounted) setState(() => _watchingLoading = false);
    }
  }

  Future<void> _loadTrending() async {
    setState(() => _trendingLoading = true);
    try {
      if (widget.isAuthenticated) {
        final result = await widget.authClient.trendingThisSeason();
        if (mounted) setState(() => _trending = result.items);
      } else {
        final result = await widget.unauthClient.trendingThisSeason();
        if (mounted) setState(() => _trending = result.items);
      }
    } catch (_) {
      // Silently handle
    } finally {
      if (mounted) setState(() => _trendingLoading = false);
    }
  }

  Future<void> _loadWatching() async {
    if (!widget.isAuthenticated) return;
    setState(() => _watchingLoading = true);
    try {
      final result = await widget.authClient.searchAnime(
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
      if (widget.isAuthenticated) {
        final result = await widget.authClient.searchAnime(
          params: const AuthenticatedAnimeSearchParams(perPage: 15),
        );
        if (mounted) setState(() => _topRated = result.items);
      } else {
        final result = await widget.unauthClient.searchAnime(
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
      if (widget.isAuthenticated) {
        final result = await widget.authClient.searchAnime(
          params: AuthenticatedAnimeSearchParams(genres: [random], perPage: 15),
        );
        if (mounted) setState(() => _randomGenre = result.items);
      } else {
        final result = await widget.unauthClient.searchAnime(
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
                      avatarUrl: widget.avatarUrl,
                      userName: widget.userName,
                      isLoading: widget.isAuthLoading,
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
          if (!widget.isAuthenticated)
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
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 24,
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sign in with AniList to track progress & get recommendations',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: widget.onLoginTap,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Login'),
                      ),
                    ],
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
            child: AnimeHorizontalList(
              anime: _trending,
              isLoading: _trendingLoading,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Currently Watching (authenticated only)
          if (widget.isAuthenticated) ...[
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
              child: AnimeHorizontalList(
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
            child: AnimeHorizontalList(
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
            child: AnimeHorizontalList(
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
