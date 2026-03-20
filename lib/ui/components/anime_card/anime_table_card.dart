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

class AnimeTableCard extends StatefulWidget {
  final AnilistAnimeBase anime;
  final VoidCallback? onTap;

  const AnimeTableCard({super.key, required this.anime, this.onTap});

  @override
  State<AnimeTableCard> createState() => _AnimeTableCardState();
}

class _AnimeTableCardState extends State<AnimeTableCard> with CardHoverMixin {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;
    final anime = widget.anime;
    final mobile = isMobile(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardHeight = mobile
        ? (screenWidth < 400 ? 106.0 : 122.0)
        : (screenWidth < Breakpoints.tablet ? 134.0 : 152.0);
    final coverWidth = screenWidth < Breakpoints.tablet ? 78.0 : 92.0;
    final chipFontSize = mobile ? 9.5 : 10.5;
    final imageUrl = anime.coverImage?.best;
    final title = anime.title.display;
    final score = anime.averageScore;

    final placeholderColor = ext.randomColour(anime.id);

    final seasonLabel = anime.seasonLabel;

    final statusLabel = anime.status?.toDisplayLabel();

    final genreChips = anime.genres
        .take(mobile ? 4 : 6)
        .map((g) => GenreTag(name: g.toGraphql(), fontSize: chipFontSize))
        .toList();

    final coverChild = AnimeCoverImage(
      imageUrl: imageUrl,
      placeholderColor: placeholderColor,
    );

    Widget content;
    if (mobile) {
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
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: MediaListStatusDot(anime: anime, size: 8),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
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
                            _MiniStat(anime.format!.toDisplayLabel(), theme),
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
      content = SizedBox(
        height: cardHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: coverWidth, child: coverChild),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: MediaListStatusDot(anime: anime, size: 9),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (anime.genres.isNotEmpty)
                      Wrap(spacing: 5, runSpacing: 4, children: genreChips),
                  ],
                ),
              ),
            ),
            if (score != null)
              SizedBox(
                width: 84,
                child: _TabularCol(
                  top: AnimeScoreBadge(score: score),
                  theme: theme,
                ),
              ),
            if (anime.format != null || anime.episodes != null)
              SizedBox(
                width: 110,
                child: _TabularCol(
                  top: anime.format != null
                      ? Text(
                          anime.format!.toDisplayLabel(),
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
      child: buildHoverableCard(
        ext: ext,
        theme: theme,
        onTap: widget.onTap,
        child: content,
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
      '\u00b7',
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
