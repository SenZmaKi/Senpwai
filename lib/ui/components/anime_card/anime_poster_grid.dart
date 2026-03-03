import 'package:flutter/material.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/ui/components/anime_card/anime_poster_card.dart';
import 'package:senpwai/ui/components/shimmer_card.dart';
import 'package:senpwai/ui/shared/responsive.dart';

class AnimePosterGrid extends StatelessWidget {
  final List<AnilistAnimeBase> anime;
  final bool isLoading;
  final bool loadingMore;
  final int crossAxisCount;

  const AnimePosterGrid({
    super.key,
    required this.anime,
    this.isLoading = false,
    this.loadingMore = false,
    required this.crossAxisCount,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = gridSpacing(context);
    final aspectRatio = gridChildAspectRatio(context);

    if (isLoading) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: aspectRatio,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
        ),
        itemCount: crossAxisCount * 2,
        itemBuilder: (_, __) => const ShimmerCard(),
      );
    }

    if (anime.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 8),
              Text(
                'No results found',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final shimmerCount = loadingMore ? crossAxisCount : 0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: anime.length + shimmerCount,
      itemBuilder: (_, i) => i < anime.length
          ? AnimePosterCard(anime: anime[i])
          : const ShimmerCard(),
    );
  }
}
