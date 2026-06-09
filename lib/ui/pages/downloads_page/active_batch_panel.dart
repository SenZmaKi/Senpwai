import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/ui/components/confirm_dialog.dart';
import 'package:senpwai/ui/pages/downloads_page/batch_big_progress_bar.dart';
import 'package:senpwai/ui/pages/downloads_page/batch_metrics_strip.dart';
import 'package:senpwai/ui/pages/downloads_page/download_batch_snapshot.dart';
import 'package:senpwai/ui/pages/downloads_page/download_status_style.dart';
import 'package:senpwai/ui/pages/downloads_page/next_in_queue_rail.dart';
import 'package:senpwai/ui/shared/responsive.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

/// Hero panel at the top of the Downloads page.
/// Overall progress + aggregate speed/ETA + pause/resume/dequeue,
/// sitting next to a richer next-in-queue rail.
class ActiveBatchPanel extends ConsumerWidget {
  final DownloadBatchSnapshot snapshot;
  final List<DownloadBatchSnapshot> upcoming;
  final int queuedBatchCount;
  final VoidCallback onOpenQueue;

  const ActiveBatchPanel({
    super.key,
    required this.snapshot,
    required this.upcoming,
    required this.queuedBatchCount,
    required this.onOpenQueue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = !isMobile(context);
    final panel = _Panel(snapshot: snapshot);
    final rail = NextInQueueRail(
      upcoming: upcoming,
      totalQueued: queuedBatchCount,
      onOpenQueue: onOpenQueue,
    );
    if (wide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 7, child: panel),
            const SizedBox(width: 14),
            Expanded(flex: 3, child: rail),
          ],
        ),
      );
    }
    return Column(children: [panel, const SizedBox(height: 12), rail]);
  }
}

class _Panel extends ConsumerWidget {
  final DownloadBatchSnapshot snapshot;
  const _Panel({required this.snapshot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final senpwai = theme.extension<SenpwaiThemeExtension>();
    final notifier = ref.read(DownloadManagerNotifier.provider.notifier);
    final style = DownloadStatusStyle.of(theme, snapshot.status);
    final radius = senpwai?.cardRadius ?? 8;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color:
              senpwai?.cardBorderColor ??
              theme.colorScheme.outline.withValues(alpha: 0.18),
          width: senpwai?.cardBorderWidth ?? 1,
        ),
        boxShadow: senpwai?.cardShadows,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: style.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PanelHeader(snapshot: snapshot, notifier: notifier),
                    const SizedBox(height: 14),
                    BatchBigProgressBar(snapshot: snapshot, style: style),
                    const SizedBox(height: 12),
                    BatchMetricsStrip(snapshot: snapshot, style: style),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final DownloadBatchSnapshot snapshot;
  final DownloadManagerNotifier notifier;
  const _PanelHeader({required this.snapshot, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = DownloadStatusStyle.of(theme, snapshot.status);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _eyebrowFor(snapshot.status),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: style.color,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                snapshot.batch.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${snapshot.batch.source.label}  ·  ${snapshot.items.length} items'
                '  ·  ${snapshot.activeCount} active',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _BatchControls(snapshot: snapshot, notifier: notifier),
      ],
    );
  }
}

String _eyebrowFor(DownloadQueueStatus status) => switch (status) {
      DownloadQueueStatus.downloading => 'NOW DOWNLOADING',
      DownloadQueueStatus.paused => 'PAUSED',
      DownloadQueueStatus.queued => 'QUEUED',
      DownloadQueueStatus.preparing => 'PREPARING',
      DownloadQueueStatus.completed => 'COMPLETED',
      DownloadQueueStatus.failed => 'FAILED',
      DownloadQueueStatus.cancelled => 'CANCELLED',
    };

class _BatchControls extends StatelessWidget {
  final DownloadBatchSnapshot snapshot;
  final DownloadManagerNotifier notifier;
  const _BatchControls({required this.snapshot, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (snapshot.canPause)
          _CtrlBtn(
            icon: Icons.pause_rounded,
            tooltip: 'Pause batch',
            onTap: () => notifier.pauseBatch(snapshot.batch.id),
          ),
        if (snapshot.canResume)
          _CtrlBtn(
            icon: Icons.play_arrow_rounded,
            tooltip: 'Resume batch',
            color: theme.colorScheme.primary,
            onTap: () => notifier.resumeBatch(snapshot.batch.id),
          ),
        const SizedBox(width: 4),
        if (snapshot.activeCount > 0)
          _CtrlBtn(
            icon: Icons.close_rounded,
            tooltip: 'Cancel batch',
            color: theme.colorScheme.error.withValues(alpha: 0.75),
            onTap: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Cancel this batch?',
                message:
                    'This will stop "${snapshot.batch.title}" and discard '
                    'its remaining downloads. Completed files will not be '
                    'deleted.',
                confirmLabel: 'Cancel batch',
                cancelLabel: 'Keep downloading',
                destructive: true,
              );
              if (confirmed) notifier.cancelBatch(snapshot.batch.id);
            },
          ),
      ],
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback onTap;
  const _CtrlBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          foregroundColor:
              color ?? theme.colorScheme.onSurface.withValues(alpha: 0.75),
          minimumSize: const Size(38, 38),
        ),
      ),
    );
  }
}
