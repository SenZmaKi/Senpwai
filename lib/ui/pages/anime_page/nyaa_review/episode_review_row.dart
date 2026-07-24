import 'package:flutter/material.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_review/torrent_meta_row.dart';
import 'package:senpwai/ui/shared/theme/theme_extension.dart';

enum EpisodeReviewStatus { autoPlanned, manuallySwapped, unresolved }

extension on EpisodeReviewStatus {
  Color color(ThemeData theme) => switch (this) {
    EpisodeReviewStatus.autoPlanned => Colors.green,
    EpisodeReviewStatus.manuallySwapped => theme.colorScheme.primary,
    EpisodeReviewStatus.unresolved => theme.colorScheme.error,
  };

  IconData get icon => switch (this) {
    EpisodeReviewStatus.autoPlanned => Icons.auto_awesome_rounded,
    EpisodeReviewStatus.manuallySwapped => Icons.swap_horiz_rounded,
    EpisodeReviewStatus.unresolved => Icons.error_outline_rounded,
  };

  String get label => switch (this) {
    EpisodeReviewStatus.autoPlanned => 'Auto',
    EpisodeReviewStatus.manuallySwapped => 'Manual',
    EpisodeReviewStatus.unresolved => 'Unresolved',
  };
}

class EpisodeReviewRow extends StatelessWidget {
  final String episodeLabel;
  final EpisodeReviewStatus status;
  final String? torrentName;
  final TorrentMetaData? meta;
  final String? unresolvedReason;
  final bool isSwappable;
  final VoidCallback? onTap;

  const EpisodeReviewRow({
    super.key,
    required this.episodeLabel,
    required this.status,
    required this.torrentName,
    required this.meta,
    this.unresolvedReason,
    this.isSwappable = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;
    final accent = status.color(theme);
    final unresolved = status == EpisodeReviewStatus.unresolved;

    return Material(
      color: unresolved
          ? accent.withValues(alpha: 0.06)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(ext.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(ext.cardRadius),
        mouseCursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ext.cardRadius),
            border: Border.all(
              color: unresolved
                  ? accent.withValues(alpha: 0.4)
                  : ext.cardBorderColor,
              width: unresolved ? 1.2 : ext.cardBorderWidth,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accent.withValues(alpha: 0.85)),
                _EpisodeBadge(label: episodeLabel, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(status.icon, size: 13, color: accent),
                            const SizedBox(width: 5),
                            Text(
                              status.label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          torrentName ?? 'No torrent selected',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: torrentName == null
                                ? theme.colorScheme.onSurface.withValues(
                                    alpha: 0.55,
                                  )
                                : null,
                            fontStyle: torrentName == null
                                ? FontStyle.italic
                                : null,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (meta != null) ...[
                          const SizedBox(height: 8),
                          TorrentMetaRow(data: meta!, compact: true),
                        ] else if (unresolvedReason != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            unresolvedReason!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (isSwappable)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    child: Icon(
                      unresolved
                          ? Icons.add_circle_outline_rounded
                          : Icons.chevron_right_rounded,
                      size: 22,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
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

class _EpisodeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _EpisodeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border(right: BorderSide(color: color.withValues(alpha: 0.18))),
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            height: 1.05,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
