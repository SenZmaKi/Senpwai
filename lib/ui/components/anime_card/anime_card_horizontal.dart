import 'package:flutter/material.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/settings/models.dart';
import 'package:senpwai/ui/components/anime_card/anime_landscape_card.dart';
import 'package:senpwai/ui/components/anime_card/anime_poster_card.dart';
import 'package:senpwai/ui/components/anime_card/anime_table_card.dart';
import 'package:senpwai/ui/components/shimmer_card.dart';
import 'package:senpwai/ui/shared/responsive.dart';

class AnimeCardHorizontal extends StatefulWidget {
  final List<AnilistAnimeBase> anime;
  final CardViewMode viewMode;
  final bool isLoading;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;

  const AnimeCardHorizontal({
    super.key,
    required this.anime,
    required this.viewMode,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.onLoadMore,
  });

  @override
  State<AnimeCardHorizontal> createState() => _AnimeCardHorizontalState();
}

class _AnimeCardHorizontalState extends State<AnimeCardHorizontal> {
  final _scrollController = ScrollController();
  static const _scrollThreshold = 200.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScroll() {
    if (widget.isLoadingMore || widget.onLoadMore == null) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - _scrollThreshold) {
      widget.onLoadMore!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = horizontalPadding(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = gridSpacing(context);
        final available = constraints.maxWidth - 2 * pad;
        final (itemWidth, itemHeight) = _itemSize(context, available, spacing);

        if (widget.isLoading) {
          return SizedBox(
            height: itemHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad),
              itemCount: 15,
              separatorBuilder: (_, __) => SizedBox(width: spacing),
              itemBuilder: (_, __) =>
                  SizedBox(width: itemWidth, child: const ShimmerCard()),
            ),
          );
        }

        if (widget.anime.isEmpty) {
          return SizedBox(
            height: 120,
            child: Center(
              child: Text(
                'Nothing here yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          );
        }

        final showLoadingMore = widget.isLoadingMore;
        final totalCount = widget.anime.length + (showLoadingMore ? 3 : 0);

        return SizedBox(
          height: itemHeight,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: pad),
            itemCount: totalCount,
            separatorBuilder: (_, __) => SizedBox(width: spacing),
            itemBuilder: (_, i) {
              if (i >= widget.anime.length) {
                return SizedBox(width: itemWidth, child: const ShimmerCard());
              }
              return SizedBox(
                width: itemWidth,
                child: _buildCard(widget.anime[i]),
              );
            },
          ),
        );
      },
    );
  }

  (double, double) _itemSize(
    BuildContext context,
    double available,
    double spacing,
  ) {
    return switch (widget.viewMode) {
      CardViewMode.poster => () {
        final columns = gridCrossAxisCount(context);
        final width = (available - (columns - 1) * spacing) / columns;
        return (width, width / gridChildAspectRatio(context));
      }(),
      CardViewMode.landscape => () {
        final columns = isDesktop(context) ? 3 : (isMobile(context) ? 1 : 2);
        final width = (available - (columns - 1) * spacing) / columns;
        return (width, width / landscapeCardAspectRatio(context));
      }(),
      CardViewMode.table => (available, tableCardHeight(context) + 10),
    };
  }

  Widget _buildCard(AnilistAnimeBase anime) => switch (widget.viewMode) {
    CardViewMode.poster => AnimePosterCard(anime: anime),
    CardViewMode.landscape => AnimeLandscapeCard(anime: anime),
    CardViewMode.table => AnimeTableCard(anime: anime),
  };
}
