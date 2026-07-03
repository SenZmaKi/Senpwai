import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/ui/pages/downloads_page/download_batch_snapshot.dart';
import 'package:senpwai/ui/components/confirm_dialog.dart';
import 'package:senpwai/ui/pages/downloads_page/download_formatters.dart';
import 'package:senpwai/ui/pages/downloads_page/download_status_style.dart';
import 'package:senpwai/ui/pages/downloads_page/pulsing_progress_bar.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

/// Single-batch wrapper used in the Batch Queue page.
/// Drag handle on the left, batch summary in the middle, dequeue on the right.
class BatchQueueCard extends ConsumerWidget {
  final DownloadBatchSnapshot snapshot;
  final Widget dragHandle;
  final bool isActive;

  const BatchQueueCard({
    super.key,
    required this.snapshot,
    required this.dragHandle,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final senpwai = theme.extension<SenpwaiThemeExtension>();
    final notifier = ref.read(DownloadManagerNotifier.provider.notifier);
    final style = DownloadStatusStyle.of(theme, snapshot.status);
    final radius = senpwai?.cardRadius ?? 8;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 12, 10, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.6)
                : (senpwai?.cardBorderColor ??
                      theme.colorScheme.outline.withValues(alpha: 0.18)),
            width: senpwai?.cardBorderWidth ?? 1,
          ),
          boxShadow: senpwai?.cardShadows,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            dragHandle,
            const SizedBox(width: 8),
            Expanded(
              child: _Body(
                snapshot: snapshot,
                style: style,
                isActive: isActive,
              ),
            ),
            const SizedBox(width: 16),
            if (snapshot.activeCount > 0)
              _IconButton(
                icon: Icons.close_rounded,
                tooltip: isActive ? 'Cancel batch' : 'Remove from queue',
                color: theme.colorScheme.error.withValues(alpha: 0.75),
                onTap: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: isActive
                        ? 'Cancel this batch?'
                        : 'Remove batch from queue?',
                    message: isActive
                        ? 'This will stop "${snapshot.batch.title}" and '
                              'discard its remaining downloads. Completed '
                              'files will not be deleted.'
                        : 'This will cancel "${snapshot.batch.title}" and '
                              'discard its remaining downloads. Completed '
                              'files will not be deleted.',
                    confirmLabel: isActive ? 'Cancel batch' : 'Remove',
                    cancelLabel: isActive
                        ? 'Keep downloading'
                        : 'Keep in queue',
                    destructive: true,
                  );
                  if (confirmed) notifier.cancelBatch(snapshot.batch.id);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final DownloadBatchSnapshot snapshot;
  final DownloadStatusStyle style;
  final bool isActive;
  const _Body({
    required this.snapshot,
    required this.style,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (isActive) ...[
              Icon(
                Icons.play_circle_rounded,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'ACTIVE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                snapshot.batch.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            DownloadStatusChip(status: snapshot.status, compact: true),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${snapshot.batch.source.label}  ·  ${snapshot.items.length} items  ·  '
          '${formatDownloadBytes(snapshot.totalBytes)}  ·  '
          '${relativeDownloadTime(snapshot.batch.createdAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final senpwai = Theme.of(
              context,
            ).extension<SenpwaiThemeExtension>()!;
            final palette = senpwai.downloadColors;
            final barRadius = (senpwai.cardRadius * 0.5).clamp(0, 6).toDouble();
            return PulsingProgressBar(
              value: snapshot.progress.clamp(0.0, 1.0),
              height: 4,
              color: style.color,
              trackColor: palette.progressTrack,
              pulseColor: palette.pulseHighlight,
              pulsing:
                  isActive &&
                  (snapshot.status == DownloadQueueStatus.downloading ||
                      snapshot.status == DownloadQueueStatus.seeding),
              borderRadius: BorderRadius.circular(barRadius),
            );
          },
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(34, 34),
        ),
      ),
    );
  }
}

class BatchQueueDragGrip extends StatelessWidget {
  const BatchQueueDragGrip({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Icon(
          Icons.drag_indicator_rounded,
          size: 22,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
