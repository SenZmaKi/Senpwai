import 'package:flutter/material.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/ui/pages/downloads_page/download_batch_snapshot.dart';
import 'package:senpwai/ui/pages/downloads_page/download_formatters.dart';
import 'package:senpwai/ui/pages/downloads_page/download_status_style.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

/// Vertical rail that sits beside the active batch panel.
/// Shows up to 3 queued batches with rich metadata (status, items, size,
/// resolution counts) and links to the full Batch Queue sheet.
///
/// When [compact] is true (mobile), an empty queue collapses to just the
/// button, and a non-empty queue shows at most 1 preview with tighter padding.
class NextInQueueRail extends StatelessWidget {
  final List<DownloadBatchSnapshot> upcoming;
  final int totalQueued;
  final VoidCallback onOpenQueue;
  final bool compact;

  static const int maxPreview = 3;
  static const int maxPreviewCompact = 1;

  const NextInQueueRail({
    super.key,
    required this.upcoming,
    required this.totalQueued,
    required this.onOpenQueue,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Mobile: single compact bar — no card overhead.
    if (compact)
      return _CompactBar(
        upcoming: upcoming,
        totalQueued: totalQueued,
        onTap: onOpenQueue,
      );

    final theme = Theme.of(context);
    final senpwai = theme.extension<SenpwaiThemeExtension>();
    final radius = senpwai?.cardRadius ?? 8;
    final onSurface = theme.colorScheme.onSurface;
    final preview = upcoming.take(maxPreview).toList();
    final overflow = totalQueued - preview.length;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color:
              senpwai?.cardBorderColor ??
              theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Eyebrow(count: totalQueued),
          const SizedBox(height: 10),
          if (preview.isEmpty)
            _EmptyState(onSurface: onSurface)
          else
            for (var i = 0; i < preview.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 14,
                  thickness: 1,
                  color: onSurface.withValues(alpha: 0.08),
                ),
              _QueueRow(snapshot: preview[i], ordinal: i + 1),
            ],
          const SizedBox(height: 10),
          _OpenQueueButton(
            extra: overflow > 0 ? overflow : 0,
            onTap: onOpenQueue,
          ),
        ],
      ),
    );
  }
}

/// Single-row compact queue summary for mobile.
/// Shows: [icon] UP NEXT · <title or "Nothing queued">  (+N more)  [→]
class _CompactBar extends StatelessWidget {
  final List<DownloadBatchSnapshot> upcoming;
  final int totalQueued;
  final VoidCallback onTap;
  const _CompactBar({
    required this.upcoming,
    required this.totalQueued,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final senpwai = theme.extension<SenpwaiThemeExtension>();
    final radius = senpwai?.cardRadius ?? 8;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final primary = theme.colorScheme.primary;
    final first = upcoming.isNotEmpty ? upcoming.first : null;
    final overflow = totalQueued - 1;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color:
                  senpwai?.cardBorderColor ??
                  theme.colorScheme.outline.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.queue_music_rounded, size: 13, color: muted),
              const SizedBox(width: 6),
              Text(
                'UP NEXT',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: muted,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 12,
                color: theme.colorScheme.outline.withValues(alpha: 0.25),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: first == null
                    ? Text(
                        'Nothing queued',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    : Text(
                        first.batch.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              if (first != null && overflow > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '+$overflow',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 16, color: primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final int count;
  const _Eyebrow({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return Row(
      children: [
        Icon(Icons.queue_music_rounded, size: 14, color: muted),
        const SizedBox(width: 6),
        Text(
          'UP NEXT',
          style: theme.textTheme.labelSmall?.copyWith(
            color: muted,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.32),
              ),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}

class _QueueRow extends StatelessWidget {
  final DownloadBatchSnapshot snapshot;
  final int ordinal;
  const _QueueRow({required this.snapshot, required this.ordinal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = DownloadStatusStyle.of(theme, snapshot.status);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final hasProgress =
        snapshot.status == DownloadQueueStatus.paused &&
        snapshot.downloadedBytes > 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Ordinal(value: ordinal, color: style.color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      snapshot.batch.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(style.icon, size: 12, color: style.color),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${snapshot.batch.source.label}  ·  '
                '${snapshot.items.length} items  ·  '
                '${formatDownloadBytes(snapshot.totalBytes)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
              const SizedBox(height: 2),
              Text(
                hasProgress
                    ? '${(snapshot.progress * 100).toStringAsFixed(0)}% downloaded'
                          '  ·  ${relativeDownloadTime(snapshot.batch.createdAt)}'
                    : relativeDownloadTime(snapshot.batch.createdAt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: muted.withValues(alpha: 0.8),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Ordinal extends StatelessWidget {
  final int value;
  final Color color;
  const _Ordinal({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final senpwai = theme.extension<SenpwaiThemeExtension>();
    final radius = (senpwai?.cardRadius ?? 4).clamp(0, 8).toDouble();
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$value',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color onSurface;
  const _EmptyState({required this.onSurface});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 22,
            color: onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 6),
          Text(
            'No queued batches',
            style: theme.textTheme.labelSmall?.copyWith(
              color: onSurface.withValues(alpha: 0.55),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenQueueButton extends StatelessWidget {
  final int extra;
  final VoidCallback onTap;
  const _OpenQueueButton({required this.extra, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final senpwai = theme.extension<SenpwaiThemeExtension>();
    final radius = (senpwai?.cardRadius ?? 999).clamp(0, 999).toDouble();
    final primary = theme.colorScheme.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: primary.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.unfold_more_rounded, size: 14, color: primary),
                const SizedBox(width: 6),
                Text(
                  extra > 0 ? 'Open queue · +$extra more' : 'Open queue',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
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
