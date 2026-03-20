import 'package:flutter/material.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/ui/components/anime_card/anime_score_badge.dart';
import 'package:senpwai/ui/components/anime_card/card_hover_mixin.dart';
import 'package:senpwai/ui/components/anime_card/media_list_status_dot.dart';
import 'package:senpwai/ui/components/anime_cover_image.dart';
import 'package:senpwai/ui/components/genre_tag.dart';
import 'package:senpwai/ui/shared/responsive.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

class AnimeLandscapeCard extends StatefulWidget {
  final AnilistAnimeBase anime;
  final VoidCallback? onTap;

  const AnimeLandscapeCard({super.key, required this.anime, this.onTap});

  @override
  State<AnimeLandscapeCard> createState() => _AnimeLandscapeCardState();
}

class _AnimeLandscapeCardState extends State<AnimeLandscapeCard>
    with CardHoverMixin {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;
    final anime = widget.anime;
    final imageUrl = anime.coverImage?.best;
    final title = anime.title.display;
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

    final placeholderColor = ext.randomColour(anime.id);

    final seasonLabel = anime.seasonLabel;

    return buildHoverableCard(
      ext: ext,
      theme: theme,
      onTap: widget.onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: coverWidth,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimeCoverImage(
                  imageUrl: imageUrl,
                  placeholderColor: placeholderColor,
                  noImageIconSize: isSmall ? 28 : 36,
                ),
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
                          ext.imageOverlay.withValues(alpha: 0.9),
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
                      color: ext.onImageOverlay,
                      fontWeight: FontWeight.w700,
                      fontSize: titleFont,
                      height: 1.3,
                      shadows: [Shadow(blurRadius: 6, color: ext.textShadow)],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: MediaListStatusDot(
                          anime: anime,
                          size: isSmall ? 8 : 10,
                        ),
                      ),
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
                  if (anime.format != null || anime.episodes != null)
                    Text(
                      [
                        if (anime.format != null)
                          anime.format!.toDisplayLabel(),
                        if (anime.episodes != null)
                          '${anime.episodes} episodes',
                      ].join(' \u2022 '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                        fontSize: metaFont,
                      ),
                    ),
                  const SizedBox(height: 8),
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
                  if (anime.genres.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: anime.genres
                          .take(genreCount)
                          .map(
                            (g) => GenreTag(
                              name: g.toGraphql(),
                              fontSize: genreFont,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
