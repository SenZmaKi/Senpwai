import 'package:flutter/material.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/ui/components/anime_card.dart';
import 'package:senpwai/ui/components/shimmer_card.dart';

class AnimeGrid extends StatelessWidget {
  final List<AnilistAnimeBase> anime;
  final bool isLoading;
  final bool loadingMore;
  final int crossAxisCount;

  const AnimeGrid({
    super.key,
    required this.anime,
    this.isLoading = false,
    this.loadingMore = false,
    required this.crossAxisCount,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.55,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.55,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: anime.length,
          itemBuilder: (_, i) => AnimeCard(anime: anime[i]),
        ),
        if (loadingMore)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.55,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: crossAxisCount,
              itemBuilder: (_, __) => const ShimmerCard(),
            ),
          ),
      ],
    );
  }
}
