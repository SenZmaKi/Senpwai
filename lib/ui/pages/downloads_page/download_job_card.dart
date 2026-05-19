import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/ui/components/toast.dart';

class DownloadJobCard extends ConsumerWidget {
  final DownloadQueueItem item;

  const DownloadJobCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(DownloadManagerNotifier.provider.notifier);
    final progress = item.progress.clamp(0, 1).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.animeTitle} • ${item.source.label}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: item.status),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: item.status == DownloadQueueStatus.failed ||
                      item.status == DownloadQueueStatus.cancelled
                  ? null
                  : progress,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _StatLabel(
                label: 'Progress',
                value:
                    '${(progress * 100).toStringAsFixed(1)}% • ${_formatBytes(item.downloadedBytes)} / ${_formatBytes(item.totalBytes)}',
              ),
              _StatLabel(
                label: 'Speed',
                value: item.bytesPerSecond > 0
                    ? '${_formatBytes(item.bytesPerSecond.round())}/s'
                    : '—',
              ),
              _StatLabel(label: 'Folder', value: item.destinationDirectory),
            ],
          ),
          if (item.filePaths.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.filePaths.join('\n'),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ],
          if (item.errorDescription != null) ...[
            const SizedBox(height: 10),
            Text(
              item.errorDescription!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.status == DownloadQueueStatus.downloading)
                FilledButton.tonalIcon(
                  onPressed: () => notifier.pause(item.id),
                  icon: const Icon(Icons.pause_rounded, size: 18),
                  label: const Text('Pause'),
                ),
              if (item.status == DownloadQueueStatus.paused)
                FilledButton.tonalIcon(
                  onPressed: () => notifier.resume(item.id),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Resume'),
                ),
              if (!item.status.isTerminal)
                OutlinedButton.icon(
                  onPressed: () => notifier.cancel(item.id),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancel'),
                ),
              if (item.errorCopyPayload != null)
                TextButton.icon(
                  onPressed: () {
                    AppToast.showError(
                      context,
                      title: item.errorTitle ?? 'Download failed',
                      description: item.errorDescription,
                      copyPayload: item.errorCopyPayload,
                    );
                  },
                  icon: const Icon(Icons.copy_all_rounded, size: 18),
                  label: const Text('Copy error'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

class _StatusChip extends StatelessWidget {
  final DownloadQueueStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (status) {
      DownloadQueueStatus.completed => Colors.green,
      DownloadQueueStatus.failed => theme.colorScheme.error,
      DownloadQueueStatus.cancelled => theme.colorScheme.outline,
      DownloadQueueStatus.paused => Colors.amber,
      DownloadQueueStatus.preparing || DownloadQueueStatus.queued => theme.colorScheme.primary,
      DownloadQueueStatus.downloading => Colors.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatLabel extends StatelessWidget {
  final String label;
  final String value;

  const _StatLabel({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
