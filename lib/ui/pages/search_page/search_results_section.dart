import 'package:flutter/material.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/ui/components/anime_card/anime_poster_grid.dart';
import 'package:senpwai/ui/components/anime_card/anime_landscape_card.dart';
import 'package:senpwai/ui/components/anime_card/anime_table_card.dart';
import 'package:senpwai/ui/components/anime_card/card_switcher.dart';
import 'package:senpwai/ui/components/shimmer_card.dart';
import 'package:senpwai/ui/shared/responsive.dart';

class SearchResultsSection extends StatelessWidget {
  final List<AnilistAnimeBase> results;
  final bool loading;
  final bool loadingMore;
  final CardViewMode viewMode;

  const SearchResultsSection({
    super.key,
    required this.results,
    required this.loading,
    required this.loadingMore,
    required this.viewMode,
  });

  @override
  Widget build(BuildContext context) {
    return switch (viewMode) {
      CardViewMode.poster => AnimePosterGrid(
        anime: results,
        isLoading: loading,
        loadingMore: loadingMore,
        crossAxisCount: gridCrossAxisCount(context),
      ),
      CardViewMode.landscape => _buildLandscapeList(context),
      CardViewMode.table => _buildTableList(context),
    };
  }

  Widget _buildTableList(BuildContext context) {
    final theme = Theme.of(context);
    final mobile = isMobile(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final skeletonHeight = mobile
        ? (screenWidth < 400 ? 106.0 : 122.0)
        : (screenWidth < Breakpoints.tablet ? 134.0 : 152.0);

    if (loading) {
      return Column(
        children: List.generate(
          6,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(height: skeletonHeight, child: const ShimmerCard()),
          ),
        ),
      );
    }

    if (results.isEmpty) {
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
        ...results.map((anime) => AnimeTableCard(anime: anime)),
        if (loadingMore)
          ...List.generate(
            2,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                height: skeletonHeight,
                child: const ShimmerCard(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLandscapeList(BuildContext context) {
    final theme = Theme.of(context);
    final cols = isDesktop(context) ? 3 : (isMobile(context) ? 1 : 2);
    final landscapeRatio = landscapeCardAspectRatio(context);
    final spacing = gridSpacing(context);

    if (loading) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: landscapeRatio,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
        ),
        itemCount: cols * 3,
        itemBuilder: (_, __) => const ShimmerCard(),
      );
    }

    if (results.isEmpty) {
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

    final shimmerCount = loadingMore ? cols : 0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: landscapeRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: results.length + shimmerCount,
      itemBuilder: (_, i) => i < results.length
          ? AnimeLandscapeCard(anime: results[i])
          : const ShimmerCard(),
    );
  }
}
