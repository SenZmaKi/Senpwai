import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/ui/components/anime_cover_image.dart';
import 'package:senpwai/ui/shared/responsive.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

class AnimeInfoHeader extends StatelessWidget {
  final AnilistAnimeBase anime;

  const AnimeInfoHeader({super.key, required this.anime});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;
    final colors = theme.colorScheme;
    final desk = isDesktop(context);
    final mob = isMobile(context);
    final bannerHeight = mob ? 150.0 : (desk ? 200.0 : 175.0);
    final coverWidth = mob ? 110.0 : (desk ? 160.0 : 130.0);
    final coverHeight = coverWidth * 1.42;
    final coverOverlap = coverHeight * 0.4;
    final placeholderColor = ext.randomColour(anime.id);
    final bannerUrl = normalizeImageUrl(anime.bannerImage);

    return SliverToBoxAdapter(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Banner
          SizedBox(
            height: bannerHeight + coverOverlap,
            child: Stack(
              children: [
                if (bannerUrl != null)
                  Positioned.fill(
                    bottom: coverOverlap,
                    child: CachedNetworkImage(
                      imageUrl: bannerUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: placeholderColor.withValues(alpha: 0.2),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: placeholderColor.withValues(alpha: 0.2),
                      ),
                    ),
                  )
                else
                  Positioned.fill(
                    bottom: coverOverlap,
                    child: Container(
                      color: placeholderColor.withValues(alpha: 0.15),
                    ),
                  ),
                // Banner gradient fade
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: coverOverlap,
                  height: bannerHeight * 0.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, colors.surface],
                      ),
                    ),
                  ),
                ),
                // Surface fill below banner
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: coverOverlap,
                  child: ColoredBox(color: colors.surface),
                ),
                // Cover image + title row
                Positioned(
                  left: horizontalPadding(context),
                  right: horizontalPadding(context),
                  bottom: 0,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Cover
                      Container(
                        width: coverWidth,
                        height: coverHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(ext.cardRadius),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: AnimeCoverImage(
                          imageUrl: anime.coverImage?.best,
                          placeholderColor: placeholderColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Title + quick stats
                      Expanded(child: _TitleBlock(anime: anime)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  final AnilistAnimeBase anime;

  const _TitleBlock({required this.anime});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final nativeTitle = anime.title.native?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          anime.title.display,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        if (nativeTitle != null &&
            nativeTitle.isNotEmpty &&
            nativeTitle != anime.title.display) ...[
          const SizedBox(height: 4),
          Text(
            nativeTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 10),
        // Quick stat chips
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (anime.averageScore != null)
              _StatChip(
                icon: Icons.star_rounded,
                label: (anime.averageScore! / 10).toStringAsFixed(1),
                color: _scoreColor(anime.averageScore!),
              ),
            if (anime.format != null)
              _StatChip(
                icon: Icons.tv_rounded,
                label: anime.format!.toDisplayLabel(),
              ),
            if (anime.episodes != null)
              _StatChip(
                icon: Icons.movie_filter_rounded,
                label: '${anime.episodes} eps',
              ),
            if (anime.status != null)
              _StatChip(
                icon: _statusIcon(anime.status!),
                label: anime.status!.toDisplayLabel(),
                color: _statusColor(anime.status!),
              ),
          ],
        ),
      ],
    );
  }

  Color _scoreColor(double score) {
    if (score >= 75) return const Color(0xFF4CAF50);
    if (score >= 50) return const Color(0xFFFFC107);
    return const Color(0xFFF44336);
  }

  IconData _statusIcon(AnilistAiringStatus status) => switch (status) {
    AnilistAiringStatus.finished => Icons.check_circle_outline,
    AnilistAiringStatus.releasing => Icons.play_circle_outline,
    AnilistAiringStatus.notYetReleased => Icons.schedule,
    AnilistAiringStatus.cancelled => Icons.cancel_outlined,
    AnilistAiringStatus.hiatus => Icons.pause_circle_outline,
  };

  Color _statusColor(AnilistAiringStatus status) => switch (status) {
    AnilistAiringStatus.finished => const Color(0xFF4CAF50),
    AnilistAiringStatus.releasing => const Color(0xFF2196F3),
    AnilistAiringStatus.notYetReleased => const Color(0xFF9E9E9E),
    AnilistAiringStatus.cancelled => const Color(0xFFF44336),
    AnilistAiringStatus.hiatus => const Color(0xFFFF9800),
  };
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _StatChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipColor.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: chipColor,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact metadata: genres as chips + inline detail text.
class AnimeMetadataSection extends StatelessWidget {
  final AnilistAnimeBase anime;

  const AnimeMetadataSection({super.key, required this.anime});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final pad = horizontalPadding(context);

    // Build a single inline summary string
    final parts = <String>[
      if (anime.seasonLabel.isNotEmpty) anime.seasonLabel,
      if (anime.startDate != null)
        _formatDateRange(anime.startDate, anime.endDate),
    ];

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Genres
            if (anime.genres.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: anime.genres.map((g) {
                  final ext = theme.extension<SenpwaiThemeExtension>()!;
                  final hash = g.toGraphql().codeUnits.fold(
                    0,
                    (int p, int c) => p * 31 + c,
                  );
                  final tagColor = ext.randomColour(hash);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: tagColor.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      g.toGraphql(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tagColor,
                        fontSize: 10,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],
            // Inline detail line
            if (parts.isNotEmpty)
              Text(
                parts.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.55),
                  height: 1.4,
                ),
              ),
            // Next episode countdown
            if (anime.nextEpisodeAiring != null && anime.episode != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 13, color: colors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Ep ${anime.episode} ${_formatRelativeDate(anime.nextEpisodeAiring!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.year}';

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null) return '?';
    final s = _fmtDate(start);
    if (end == null) return '$s – ongoing';
    return '$s – ${_fmtDate(end)}';
  }

  String _formatRelativeDate(DateTime date) {
    final diff = date.difference(DateTime.now());
    if (diff.inDays > 0) return 'in ${diff.inDays}d';
    if (diff.inHours > 0) return 'in ${diff.inHours}h';
    return 'soon';
  }
}
