import 'package:flutter/material.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/ui/components/anime_card/anime_score_badge.dart';
import 'package:senpwai/ui/components/anime_card/card_hover_mixin.dart';
import 'package:senpwai/ui/components/anime_card/media_list_status_dot.dart';
import 'package:senpwai/ui/components/anime_cover_image.dart';
import 'package:senpwai/ui/components/overlay_chip.dart';
import 'package:senpwai/ui/shared/responsive.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

class AnimePosterCard extends StatefulWidget {
  final AnilistAnimeBase anime;
  final VoidCallback? onTap;

  const AnimePosterCard({super.key, required this.anime, this.onTap});

  @override
  State<AnimePosterCard> createState() => _AnimePosterCardState();
}

class _AnimePosterCardState extends State<AnimePosterCard> with CardHoverMixin {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;
    final anime = widget.anime;
    final imageUrl = anime.coverImage?.best;
    final title = anime.title.display;
    final score = anime.averageScore;

    final w = MediaQuery.sizeOf(context).width;
    final isSmall = w < 380;
    final desk = w >= Breakpoints.desktop;

    final placeholderColor = ext.randomColour(anime.id);

    final badgeInset = isSmall ? 4.0 : (desk ? 8.0 : 6.0);
    final formatFontSize = isSmall ? 7.0 : (desk ? 9.0 : 8.0);
    final titlePadH = isSmall ? 6.0 : (desk ? 10.0 : 8.0);
    final titlePadTop = isSmall ? 5.0 : 6.0;
    final titlePadBottom = isSmall ? 6.0 : (desk ? 10.0 : 8.0);
    final subInfoFont = desk ? 11.0 : 10.0;
    final gradH = isSmall ? 52.0 : (desk ? 72.0 : 64.0);
    final placeholderIcon = isSmall ? 30.0 : (desk ? 44.0 : 40.0);

    return buildHoverableCard(
      ext: ext,
      theme: theme,
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimeCoverImage(
                  imageUrl: imageUrl,
                  placeholderColor: placeholderColor,
                  noImageIconSize: placeholderIcon,
                ),
                if (score != null)
                  Positioned(
                    top: badgeInset,
                    right: badgeInset,
                    child: AnimeScoreBadge(score: score),
                  ),
                if (anime.format != null)
                  Positioned(
                    top: badgeInset,
                    left: badgeInset,
                    child: OverlayChip(
                      child: Text(
                        anime.format!.toDisplayLabel(),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: formatFontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: gradH,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          (theme.cardTheme.color ?? theme.colorScheme.surface)
                              .withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              titlePadH,
              titlePadTop,
              titlePadH,
              titlePadBottom,
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
                        size: isSmall ? 8 : (desk ? 10 : 9),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                if (anime.episodes != null || anime.status != null)
                  Text(
                    [
                      if (anime.episodes != null) '${anime.episodes} eps',
                      if (anime.status != null) anime.status!.toDisplayLabel(),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: subInfoFont,
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
