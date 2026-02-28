import 'package:flutter/material.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/ui/components/anime_card.dart';
import 'package:senpwai/ui/components/shimmer_card.dart';

class AnimeHorizontalList extends StatelessWidget {
  final List<AnilistAnimeBase> anime;
  final bool isLoading;
  final double itemWidth;
  final double itemHeight;

  const AnimeHorizontalList({
    super.key,
    required this.anime,
    this.isLoading = false,
    this.itemWidth = 150,
    this.itemHeight = 270,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: itemHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) =>
              SizedBox(width: itemWidth, child: const ShimmerCard()),
        ),
      );
    }

    if (anime.isEmpty) {
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

    return SizedBox(
      height: itemHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: anime.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          return SizedBox(
            width: itemWidth,
            child: AnimeCard(anime: anime[i]),
          );
        },
      ),
    );
  }
}
