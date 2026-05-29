import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/ui/components/toast.dart';

class HistoryDownloadCard extends ConsumerWidget {
  final DownloadQueueItem item;

  const HistoryDownloadCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(DownloadManagerNotifier.provider.notifier);
    final isFailed = item.status == DownloadQueueStatus.failed;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFailed
              ? theme.colorScheme.error.withValues(alpha: 0.2)
              : theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MainRow(item: item, onDismiss: () => notifier.dismiss(item.id)),
          if (isFailed && item.errorDescription != null) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.08),
            ),
            _ErrorRow(item: item),
          ],
        ],
      ),
    );
  }
}

class _MainRow extends StatelessWidget {
  final DownloadQueueItem item;
  final VoidCallback onDismiss;

  const _MainRow({required this.item, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          _StatusIcon(status: item.status),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.animeTitle} · ${item.source.label} · ${_relativeTime(item.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              tooltip: 'Dismiss',
              onPressed: onDismiss,
              style: IconButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.4,
                ),
                minimumSize: const Size(32, 32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ErrorRow extends ConsumerWidget {
  final DownloadQueueItem item;

  const _ErrorRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              item.errorDescription!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
          ),
          if (item.errorCopyPayload != null) ...[
            const SizedBox(width: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: InkWell(
                onTap: () => AppToast.showError(
                  context,
                  title: item.errorTitle ?? 'Download failed',
                  description: item.errorDescription,
                  copyPayload: item.errorCopyPayload,
                ),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.copy_all_rounded,
                        size: 13,
                        color: theme.colorScheme.error.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Copy error',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.error.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final DownloadQueueStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (status) {
      DownloadQueueStatus.completed => (
        Icons.check_circle_rounded,
        Colors.green,
      ),
      DownloadQueueStatus.failed => (
        Icons.error_rounded,
        theme.colorScheme.error,
      ),
      DownloadQueueStatus.cancelled => (
        Icons.cancel_rounded,
        theme.colorScheme.outline,
      ),
      _ => (Icons.circle_outlined, theme.colorScheme.outline),
    };
    return Icon(icon, size: 20, color: color);
  }
}
