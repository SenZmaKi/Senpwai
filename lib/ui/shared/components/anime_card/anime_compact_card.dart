import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/shared/shared.dart';
import 'package:senpwai/ui/shared/components/anime_card/anime_score_badge.dart';
import 'package:senpwai/ui/shared/responsive.dart';
import 'package:senpwai/ui/shared/theme.dart';

class AnimeCompactCard extends StatelessWidget {
  final AnilistAnimeBase anime;
  final VoidCallback? onTap;

  const AnimeCompactCard({super.key, required this.anime, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;
    final imageUrl = anime.coverImage?.large ?? anime.coverImage?.medium;
    final title =
        anime.title.english ?? anime.title.romaji ?? anime.title.native ?? '?';
    final score = anime.averageScore;
    final desc = anime.description;

    final w = MediaQuery.sizeOf(context).width;
    final isSmall = w < 380;
    final mob = w < Breakpoints.mobile;
    final desk = w >= Breakpoints.desktop;
    final coverWidth = isSmall ? 100.0 : (mob ? 110.0 : (desk ? 140.0 : 130.0));
    final gradientH = isSmall ? 70.0 : 90.0;
    final titleFont = isSmall ? 10.0 : 11.0;
    final seasonFont = isSmall ? 11.0 : 12.0;
    final metaFont = isSmall ? 10.0 : 11.0;
    final descMaxLines = isSmall ? 3 : 5;
    final genreFont = isSmall ? 9.0 : 10.0;
    final genreCount = isSmall ? 3 : 4;

    final seasonLabel = [
      if (anime.season != null)
        anime.season!.toGraphql().toLowerCase().capitalize(),
      if (anime.seasonYear != null) '${anime.seasonYear}',
    ].join(' ');

    return Material(
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(ext.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ext.cardRadius),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ext.cardRadius),
          child: SizedBox(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: portrait cover with title overlay
                SizedBox(
                  width: coverWidth,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null)
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: ext.shimmerBase),
                          errorWidget: (_, __, ___) => Container(
                            color: ext.shimmerBase,
                            child: Icon(
                              Icons.broken_image,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          color: ext.shimmerBase,
                          child: Icon(
                            Icons.movie_outlined,
                            size: isSmall ? 28 : 36,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                      // Gradient + title at bottom
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: gradientH,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.9),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Text(
                          title,
                          maxLines: isSmall ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: titleFont,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Right: metadata panel
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isSmall ? 10 : 12,
                      isSmall ? 8 : 10,
                      isSmall ? 8 : 10,
                      isSmall ? 8 : 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Season / year + score
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                seasonLabel.isNotEmpty
                                    ? seasonLabel
                                    : 'Unknown Season',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.9,
                                  ),
                                  fontSize: seasonFont,
                                ),
                              ),
                            ),
                            if (score != null) ...[
                              const SizedBox(width: 6),
                              AnimeScoreBadge(score: score),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        // Format + episodes
                        if (anime.format != null || anime.episodes != null)
                          Text(
                            [
                              if (anime.format != null)
                                anime.format!.toGraphql().replaceAll('_', ' '),
                              if (anime.episodes != null)
                                '${anime.episodes} episodes',
                            ].join(' • '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                              fontSize: metaFont,
                            ),
                          ),
                        const SizedBox(height: 8),
                        // Description
                        if (desc != null)
                          Expanded(
                            child: Text(
                              desc.replaceAll(RegExp(r'<[^>]*>'), ''),
                              maxLines: descMaxLines,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.65,
                                ),
                                fontSize: metaFont,
                                height: 1.5,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        // Genre tags
                        if (anime.genres.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: anime.genres.take(genreCount).map((g) {
                              final name = g.toGraphql();
                              final gHash = name.codeUnits.fold(
                                0,
                                (int p, int c) => p * 31 + c,
                              );
                              final color =
                                  ext.genrePalette[gHash.abs() %
                                      ext.genrePalette.length];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: genreFont,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
