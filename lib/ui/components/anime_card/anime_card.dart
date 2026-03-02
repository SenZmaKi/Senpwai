import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/ui/components/anime_card/anime_score_badge.dart';
import 'package:senpwai/ui/core/responsive.dart';
import 'package:senpwai/ui/core/theme.dart';

class AnimeCard extends StatefulWidget {
  final AnilistAnimeBase anime;
  final VoidCallback? onTap;

  const AnimeCard({super.key, required this.anime, this.onTap});

  @override
  State<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;
    final anime = widget.anime;
    final imageUrl = anime.coverImage?.large ?? anime.coverImage?.medium;
    final title =
        anime.title.english ?? anime.title.romaji ?? anime.title.native ?? '?';
    final score = anime.averageScore;

    final w = MediaQuery.sizeOf(context).width;
    final isSmall = w < 380;
    final desk = w >= Breakpoints.desktop;

    final badgeInset = isSmall ? 4.0 : (desk ? 8.0 : 6.0);
    final formatFontSize = isSmall ? 7.0 : (desk ? 9.0 : 8.0);
    final titlePadH = isSmall ? 6.0 : (desk ? 10.0 : 8.0);
    final titlePadTop = isSmall ? 5.0 : 6.0;
    final titlePadBottom = isSmall ? 6.0 : (desk ? 10.0 : 8.0);
    final subInfoFont = desk ? 11.0 : 10.0;
    final gradH = isSmall ? 52.0 : (desk ? 72.0 : 64.0);
    final placeholderIcon = isSmall ? 30.0 : (desk ? 44.0 : 40.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(ext.cardRadius),
              border: ext.cardBorderWidth > 0
                  ? Border.all(
                      color: ext.cardBorderColor,
                      width: ext.cardBorderWidth,
                    )
                  : null,
              boxShadow: _hovered
                  ? ext.cardShadows
                        .map(
                          (s) => BoxShadow(
                            color: s.color.withValues(alpha: s.color.a * 1.6),
                            blurRadius: s.blurRadius * 1.5,
                            offset: s.offset,
                          ),
                        )
                        .toList()
                  : ext.cardShadows,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
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
                            size: placeholderIcon,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.2,
                            ),
                          ),
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
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmall ? 5 : 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withValues(
                                alpha: 0.9,
                              ),
                              borderRadius: BorderRadius.circular(
                                ext.cardRadius.clamp(0, 8),
                              ),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.4,
                                ),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              anime.format!.toGraphql().replaceAll('_', ' '),
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
                                (theme.cardTheme.color ??
                                        theme.colorScheme.surface)
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
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (anime.episodes != null || anime.status != null)
                        Text(
                          [
                            if (anime.episodes != null) '${anime.episodes} eps',
                            if (anime.status != null)
                              anime.status!
                                  .toGraphql()
                                  .replaceAll('_', ' ')
                                  .toLowerCase(),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                            fontSize: subInfoFont,
                          ),
                        ),
                    ],
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
