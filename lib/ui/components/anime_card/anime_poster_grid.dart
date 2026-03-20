import 'package:flutter/material.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/ui/components/anime_card/anime_poster_card.dart';
import 'package:senpwai/ui/components/empty_results_placeholder.dart';
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
      return const EmptyResultsPlaceholder();
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
