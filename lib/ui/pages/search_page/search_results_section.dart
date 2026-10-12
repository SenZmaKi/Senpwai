import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/settings/notifier.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/settings/models.dart';
import 'package:senpwai/ui/components/anime_card/anime_landscape_card.dart';
import 'package:senpwai/ui/components/anime_card/anime_poster_card.dart';
import 'package:senpwai/ui/components/anime_card/anime_table_card.dart';
import 'package:senpwai/ui/components/empty_results_placeholder.dart';
import 'package:senpwai/ui/components/shimmer_card.dart';
import 'package:senpwai/ui/shared/responsive.dart';

class SearchResultsSection extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = ref.watch(
      AppSettingsNotifier.provider.select(
        (settings) => settings.appearance.compactCards,
      ),
    );
    return switch (viewMode) {
      CardViewMode.poster => _buildPosterGrid(context, compact),
      CardViewMode.landscape => _buildLandscapeList(context, compact),
      CardViewMode.table => _buildTableList(context, compact),
    };
  }

  Widget _buildPosterGrid(BuildContext context, bool compact) {
    final cols =
        gridCrossAxisCount(context) + (compact && !isMobile(context) ? 1 : 0);
    final spacing = gridSpacing(context) * (compact ? 0.6 : 1);
    final aspectRatio = gridChildAspectRatio(context);

    if (loading) {
      return _ResultsGrid(
        crossAxisCount: cols,
        aspectRatio: aspectRatio,
        spacing: spacing,
        itemCount: cols * 2,
        itemBuilder: (_, __) => const ShimmerCard(),
      );
    }

    if (results.isEmpty) {
      return const SliverToBoxAdapter(child: EmptyResultsPlaceholder());
    }

    final shimmerCount = loadingMore ? cols : 0;
    return _ResultsGrid(
      crossAxisCount: cols,
      aspectRatio: aspectRatio,
      spacing: spacing,
      itemCount: results.length + shimmerCount,
      itemBuilder: (_, i) => i < results.length
          ? AnimePosterCard(anime: results[i])
          : const ShimmerCard(),
    );
  }

  Widget _buildTableList(BuildContext context, bool compact) {
    final skeletonHeight = tableCardHeight(context);

    if (loading) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, __) => Padding(
            padding: EdgeInsets.only(bottom: compact ? 4 : 10),
            child: SizedBox(height: skeletonHeight, child: const ShimmerCard()),
          ),
          childCount: 6,
        ),
      );
    }

    if (results.isEmpty) {
      return const SliverToBoxAdapter(child: EmptyResultsPlaceholder());
    }

    final shimmerCount = loadingMore ? 2 : 0;
    return SliverList(
      delegate: SliverChildBuilderDelegate((_, i) {
        if (i < results.length) {
          return AnimeTableCard(anime: results[i]);
        }
        return Padding(
          padding: EdgeInsets.only(bottom: compact ? 4 : 10),
          child: SizedBox(height: skeletonHeight, child: const ShimmerCard()),
        );
      }, childCount: results.length + shimmerCount),
    );
  }

  Widget _buildLandscapeList(BuildContext context, bool compact) {
    final cols =
        (isDesktop(context) ? 3 : (isMobile(context) ? 1 : 2)) +
        (compact && !isMobile(context) ? 1 : 0);
    final landscapeRatio = landscapeCardAspectRatio(context);
    final spacing = gridSpacing(context) * (compact ? 0.6 : 1);

    if (loading) {
      return _ResultsGrid(
        crossAxisCount: cols,
        aspectRatio: landscapeRatio,
        spacing: spacing,
        itemCount: cols * 3,
        itemBuilder: (_, __) => const ShimmerCard(),
      );
    }

    if (results.isEmpty) {
      return const SliverToBoxAdapter(child: EmptyResultsPlaceholder());
    }

    final shimmerCount = loadingMore ? cols : 0;

    return _ResultsGrid(
      crossAxisCount: cols,
      aspectRatio: landscapeRatio,
      spacing: spacing,
      itemCount: results.length + shimmerCount,
      itemBuilder: (_, i) => i < results.length
          ? AnimeLandscapeCard(anime: results[i])
          : const ShimmerCard(),
    );
  }
}

class _ResultsGrid extends StatelessWidget {
  final int crossAxisCount;
  final double aspectRatio;
  final double spacing;
  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  const _ResultsGrid({
    required this.crossAxisCount,
    required this.aspectRatio,
    required this.spacing,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      delegate: SliverChildBuilderDelegate(itemBuilder, childCount: itemCount),
    );
  }
}
