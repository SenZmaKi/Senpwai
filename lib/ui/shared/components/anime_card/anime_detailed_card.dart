import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/shared/shared.dart';
import 'package:senpwai/ui/shared/components/anime_card/anime_score_badge.dart';
import 'package:senpwai/ui/shared/responsive.dart';
import 'package:senpwai/ui/shared/theme.dart';

class AnimeDetailedCard extends StatefulWidget {
  final AnilistAnimeBase anime;
  final VoidCallback? onTap;

  const AnimeDetailedCard({super.key, required this.anime, this.onTap});

  @override
  State<AnimeDetailedCard> createState() => _AnimeDetailedCardState();
}

class _AnimeDetailedCardState extends State<AnimeDetailedCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;
    final anime = widget.anime;
    final mobile = isMobile(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Responsive sizing based on available screen width
    final cardHeight = mobile
        ? (screenWidth < 400 ? 106.0 : 122.0)
        : (screenWidth < Breakpoints.tablet ? 134.0 : 152.0);
    final coverWidth = screenWidth < Breakpoints.tablet ? 78.0 : 92.0;
    final chipFontSize = mobile ? 9.5 : 10.5;
    final imageUrl = anime.coverImage?.large ?? anime.coverImage?.medium;
    final title =
        anime.title.english ?? anime.title.romaji ?? anime.title.native ?? '?';
    final score = anime.averageScore;

    final seasonLabel = [
      if (anime.season != null)
        anime.season!.toGraphql().toLowerCase().capitalize(),
      if (anime.seasonYear != null) '${anime.seasonYear}',
    ].join(' ');

    final statusLabel = anime.status
        ?.toGraphql()
        .replaceAll('_', ' ')
        .toLowerCase()
        .capitalize();

    final genreChips = anime.genres.take(mobile ? 4 : 6).map((g) {
      final name = g.toGraphql();
      final hash = name.codeUnits.fold(0, (int p, int c) => p * 31 + c);
      final color = ext.genrePalette[hash.abs() % ext.genrePalette.length];
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: color,
            fontSize: chipFontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      );
    }).toList();

    final coverChild = imageUrl != null
        ? CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: ext.shimmerBase),
            errorWidget: (_, __, ___) => Container(
              color: ext.shimmerBase,
              child: Icon(
                Icons.broken_image,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          )
        : Container(
            color: ext.shimmerBase,
            child: Icon(
              Icons.movie_outlined,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
          );

    Widget content;
    if (mobile) {
      // Mobile: 2-column (image | title + genres + compact stats row)
      content = SizedBox(
        height: cardHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(aspectRatio: 0.67, child: coverChild),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (anime.genres.isNotEmpty)
                      Wrap(spacing: 4, runSpacing: 3, children: genreChips),
                    const Spacer(),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (score != null) ...[
                            AnimeScoreBadge(score: score),
                            _Dot(theme),
                          ],
                          if (anime.format != null) ...[
                            _MiniStat(
                              anime.format!.toGraphql().replaceAll('_', ' '),
                              theme,
                            ),
                            if (anime.episodes != null ||
                                seasonLabel.isNotEmpty ||
                                statusLabel != null)
                              _Dot(theme),
                          ],
                          if (anime.episodes != null) ...[
                            _MiniStat('${anime.episodes} eps', theme),
                            if (seasonLabel.isNotEmpty || statusLabel != null)
                              _Dot(theme),
                          ],
                          if (seasonLabel.isNotEmpty) ...[
                            _MiniStat(seasonLabel, theme),
                            if (statusLabel != null) _Dot(theme),
                          ],
                          if (statusLabel != null)
                            _MiniStat(statusLabel, theme),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Desktop/tablet: AniList-style tabular layout
      // Col 1: image | Col 2: title+genres | Col 3: score | Col 4: format+eps | Col 5: season+status
      content = SizedBox(
        height: cardHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: coverWidth, child: coverChild),
            // Col 2: Title + genres (flexible, takes remaining space)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (anime.genres.isNotEmpty)
                      Wrap(spacing: 5, runSpacing: 4, children: genreChips),
                  ],
                ),
              ),
            ),
            // Col 3: Score
            if (score != null)
              SizedBox(
                width: 84,
                child: _TabularCol(
                  top: AnimeScoreBadge(score: score),
                  theme: theme,
                ),
              ),
            // Col 4: Format + episodes
            if (anime.format != null || anime.episodes != null)
              SizedBox(
                width: 110,
                child: _TabularCol(
                  top: anime.format != null
                      ? Text(
                          anime.format!.toGraphql().replaceAll('_', ' '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        )
                      : null,
                  bottom: anime.episodes != null
                      ? Text(
                          '${anime.episodes} episodes',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                            fontSize: 11,
                          ),
                        )
                      : null,
                  theme: theme,
                ),
              ),
            // Col 5: Season + status
            if (seasonLabel.isNotEmpty || statusLabel != null)
              SizedBox(
                width: 110,
                child: _TabularCol(
                  top: seasonLabel.isNotEmpty
                      ? Text(
                          seasonLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        )
                      : null,
                  bottom: statusLabel != null
                      ? Text(
                          statusLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                            fontSize: 11,
                          ),
                        )
                      : null,
                  theme: theme,
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
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
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ext.cardRadius),
            child: InkWell(onTap: widget.onTap, child: content),
          ),
        ),
      ),
    );
  }
}

class _TabularCol extends StatelessWidget {
  final Widget? top;
  final Widget? bottom;
  final ThemeData theme;

  const _TabularCol({this.top, this.bottom, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (top != null) top!,
          if (top != null && bottom != null) const SizedBox(height: 4),
          if (bottom != null) bottom!,
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final ThemeData theme;
  const _Dot(this.theme);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Text(
      '·',
      style: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        fontSize: 14,
      ),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  final String label;
  final ThemeData theme;
  const _MiniStat(this.label, this.theme);

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
      fontSize: 11,
    ),
  );
}
