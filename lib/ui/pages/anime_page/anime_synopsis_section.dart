import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/ui/shared/responsive.dart';

/// Expandable synopsis section with HTML-stripped plain text.
class AnimeSynopsisSection extends ConsumerStatefulWidget {
  final AnilistAnimeBase anime;

  const AnimeSynopsisSection({super.key, required this.anime});

  @override
  ConsumerState<AnimeSynopsisSection> createState() =>
      _AnimeSynopsisSectionState();
}

class _AnimeSynopsisSectionState extends ConsumerState<AnimeSynopsisSection> {
  bool _expanded = false;

  @override
  void didUpdateWidget(AnimeSynopsisSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anime.id != widget.anime.id) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      AppSettingsNotifier.provider.select(
        (settings) => settings.appearance.hideSynopses,
      ),
      (previous, next) {
        if (previous != next) setState(() => _expanded = false);
      },
    );
    final hideSynopsis = ref.watch(
      AppSettingsNotifier.provider.select(
        (settings) => settings.appearance.hideSynopses,
      ),
    );
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
            if (!hideSynopsis || _expanded)
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
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
              ),
            const SizedBox(height: 2),
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded
                    ? (hideSynopsis ? 'Hide synopsis' : 'Show less')
                    : (hideSynopsis ? 'Show synopsis' : 'Read more'),
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
