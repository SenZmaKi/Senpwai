import 'package:flutter/material.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/ui/shared/responsive.dart';

/// Expandable synopsis section with HTML-stripped plain text.
class AnimeSynopsisSection extends StatefulWidget {
  final AnilistAnimeBase anime;

  const AnimeSynopsisSection({super.key, required this.anime});

  @override
  State<AnimeSynopsisSection> createState() => _AnimeSynopsisSectionState();
}

class _AnimeSynopsisSectionState extends State<AnimeSynopsisSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final description = widget.anime.description;
    if (description == null || description.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final pad = horizontalPadding(context);
    final plainText = _stripHtml(description);

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(pad, 10, pad, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Synopsis',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            AnimatedCrossFade(
              firstChild: Text(
                plainText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.75),
                  height: 1.5,
                ),
              ),
              secondChild: Text(
                plainText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.75),
                  height: 1.5,
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
            const SizedBox(height: 2),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _expanded ? 'Show less' : 'Read more',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Naive HTML tag stripper. Handles <br>, <br/>, and common tags.
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }
}
