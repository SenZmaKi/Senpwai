import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/ui/components/anime_card/anime_score_badge.dart';
import 'package:senpwai/ui/components/genre_tag.dart';
import 'package:senpwai/ui/components/overlay_chip.dart';
import 'package:senpwai/ui/shared/responsive.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

import 'package:senpwai/ui/components/shimmer_card.dart';

class AnimeBannerCarousel extends StatefulWidget {
  final List<AnilistAnimeBase> anime;
  final bool isLoading;
  final int maxItems;
  final Duration autoScrollInterval;

  const AnimeBannerCarousel({
    super.key,
    required this.anime,
    this.isLoading = false,
    this.maxItems = 8,
    this.autoScrollInterval = const Duration(seconds: 6),
  });

  @override
  State<AnimeBannerCarousel> createState() => _AnimeBannerCarouselState();
}

class _AnimeBannerCarouselState extends State<AnimeBannerCarousel> {
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;
  bool _userInteracting = false;
  late List<AnilistAnimeBase> _items;

  List<AnilistAnimeBase> _computeItems(List<AnilistAnimeBase> anime) {
    final withBanner = anime.where((a) => a.bannerImage != null).toList()
      ..shuffle();
    return withBanner.take(widget.maxItems).toList();
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _items = _computeItems(widget.anime);
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(AnimeBannerCarousel old) {
    super.didUpdateWidget(old);
    if (old.anime != widget.anime) {
      _items = _computeItems(widget.anime);
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _restartAutoScroll();
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(widget.autoScrollInterval, (_) {
      if (_userInteracting || !mounted || _items.isEmpty) return;
      final next = (_currentPage + 1) % _items.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _restartAutoScroll() {
    _autoScrollTimer?.cancel();
    _startAutoScroll();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  double _carouselHeight(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= Breakpoints.desktop) return 320;
    if (w >= Breakpoints.tablet) return 260;
    if (w >= Breakpoints.mobile) return 220;
    return 200;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;
    final height = _carouselHeight(context);
    final items = _items;

    if (widget.isLoading) {
      return _buildShimmer(ext, height);
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Page view
          GestureDetector(
            onPanDown: (_) => _userInteracting = true,
            onPanEnd: (_) {
              _userInteracting = false;
              _restartAutoScroll();
            },
            onPanCancel: () {
              _userInteracting = false;
              _restartAutoScroll();
            },
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _BannerSlide(anime: items[index]);
              },
            ),
          ),

          // Dot indicators
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (i) {
                final active = i == _currentPage;
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                      );
                      _restartAutoScroll();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? theme.colorScheme.primary
                            : ext.onImageOverlay.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer(SenpwaiThemeExtension ext, double height) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ShimmerCard(height: height, borderRadius: ext.cardRadius),
    );
  }
}

class _BannerSlide extends StatelessWidget {
  final AnilistAnimeBase anime;

  const _BannerSlide({required this.anime});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;
    final mobile = isMobile(context);
    final desktop = isDesktop(context);

    final overlayBase = ext.imageOverlay;
    final textColor = ext.onImageOverlay;
    final shadowColor = ext.textShadow;

    final title = anime.title.display;
    final score = anime.averageScore;
    final genres = anime.genres.take(3).map((g) => g.toGraphql()).toList();

    final titleStyle = desktop
        ? theme.textTheme.headlineMedium
        : (mobile ? theme.textTheme.titleMedium : theme.textTheme.titleLarge);

    final pad = horizontalPadding(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: (anime.bannerImage)!,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: ext.randomColour(anime.id).withValues(alpha: 0.2),
          ),
          errorWidget: (_, __, ___) => Container(
            color: ext.randomColour(anime.id).withValues(alpha: 0.2),
            child: Icon(
              Icons.broken_image,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              size: 40,
            ),
          ),
        ),

        // Gradient overlay — bottom heavy
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.7, 1.0],
                colors: [
                  overlayBase.withValues(alpha: 0.1),
                  overlayBase.withValues(alpha: 0.15),
                  overlayBase.withValues(alpha: 0.55),
                  overlayBase.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
        ),

        // Left-edge gradient for extra readability
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0.0, 0.5],
                colors: [
                  overlayBase.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Metadata overlay
        Positioned(
          left: pad,
          right: pad + 40,
          bottom: 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyle?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(blurRadius: 8, color: shadowColor)],
                ),
              ),
              const SizedBox(height: 6),

              // Info row: score, format, episodes
              Row(
                children: [
                  if (score != null) ...[
                    AnimeScoreBadge(score: score),
                    const SizedBox(width: 8),
                  ],
                  if (anime.format != null) ...[
                    OverlayChip(
                      child: Text(
                        anime.format!.toDisplayLabel(),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (anime.episodes != null)
                    OverlayChip(
                      child: Text(
                        '${anime.episodes} eps',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                ],
              ),

              if (genres.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: genres
                      .map((g) => GenreTag(name: g, fontSize: mobile ? 10 : 11))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
