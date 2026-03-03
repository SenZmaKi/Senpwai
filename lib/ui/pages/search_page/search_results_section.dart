import 'package:flutter/material.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/ui/components/anime_card/anime_card_grid.dart';
import 'package:senpwai/ui/components/anime_card/anime_compact_card.dart';
import 'package:senpwai/ui/components/anime_card/anime_detailed_card.dart';
import 'package:senpwai/ui/components/anime_card/card_switcher.dart';
import 'package:senpwai/ui/core/responsive.dart';

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
      CardViewMode.grid => AnimeCardGrid(
        anime: results,
        isLoading: loading,
        loadingMore: loadingMore,
        crossAxisCount: gridCrossAxisCount(context),
      ),
      CardViewMode.compact => _buildCompactList(context),
      CardViewMode.detailed => _buildDetailedList(context),
    };
  }

  Widget _buildDetailedList(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
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
        ...results.map((anime) => AnimeDetailedCard(anime: anime)),
        if (loadingMore)
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

    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
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
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: compactRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: results.length,
          itemBuilder: (_, i) => AnimeCompactCard(anime: results[i]),
        ),
        if (loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
