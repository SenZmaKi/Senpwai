import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/ui/components/toast.dart';

class ActiveDownloadCard extends ConsumerWidget {
  final DownloadQueueItem item;

  const ActiveDownloadCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(DownloadManagerNotifier.provider.notifier);
    final progress = item.progress.clamp(0.0, 1.0);
    final isDownloading = item.status == DownloadQueueStatus.downloading;
    final isPaused = item.status == DownloadQueueStatus.paused;
    final isActive = isDownloading || isPaused;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDownloading
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.15),
          width: isDownloading ? 1.5 : 1,
        ),
        boxShadow: isDownloading
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(item: item),
          const SizedBox(height: 12),
          _ProgressSection(item: item, progress: progress),
          if (isActive) ...[
            const SizedBox(height: 12),
            _StatsRow(item: item),
          ],
          const SizedBox(height: 12),
          _ActionRow(item: item, notifier: notifier),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  final DownloadQueueItem item;
  const _CardHeader({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
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
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${item.animeTitle} · ${item.source.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _StatusBadge(status: item.status),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final DownloadQueueItem item;
  final double progress;
  const _ProgressSection({required this.item, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (progress * 100).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$pct%',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              '${_fmt(item.downloadedBytes)} / ${_fmt(item.totalBytes)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final DownloadQueueItem item;
  const _StatsRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final eta = _eta(item);
    return Wrap(
      spacing: 20,
      runSpacing: 6,
      children: [
        if (item.bytesPerSecond > 0)
          _Stat(
            label: 'Speed',
            value: '${_fmt(item.bytesPerSecond.round())}/s',
          ),
        if (eta != null) _Stat(label: 'ETA', value: eta),
        _Stat(label: 'Folder', value: item.destinationDirectory),
      ],
    );
  }

  static String? _eta(DownloadQueueItem item) {
    if (item.bytesPerSecond <= 0) return null;
    final remaining = item.totalBytes - item.downloadedBytes;
    if (remaining <= 0) return null;
    final secs = (remaining / item.bytesPerSecond).round();
    if (secs < 60) return '${secs}s';
    if (secs < 3600) return '${secs ~/ 60}m ${secs % 60}s';
    return '${secs ~/ 3600}h ${(secs % 3600) ~/ 60}m';
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

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
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final DownloadQueueItem item;
  final DownloadManagerNotifier notifier;
  const _ActionRow({required this.item, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final isDownloading = item.status == DownloadQueueStatus.downloading;
    final isPaused = item.status == DownloadQueueStatus.paused;

    return Row(
      children: [
        if (isDownloading)
          _ActionButton(
            icon: Icons.pause_rounded,
            label: 'Pause',
            onTap: () => notifier.pause(item.id),
          ),
        if (isPaused)
          _ActionButton(
            icon: Icons.play_arrow_rounded,
            label: 'Resume',
            onTap: () => notifier.resume(item.id),
          ),
        if (!item.status.isTerminal) ...[
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.close_rounded,
            label: 'Cancel',
            onTap: () => notifier.cancel(item.id),
            destructive: true,
          ),
        ],
        if (item.errorCopyPayload != null) ...[
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.copy_all_rounded,
            label: 'Copy error',
            onTap: () => AppToast.showError(
              context,
              title: item.errorTitle ?? 'Download failed',
              description: item.errorDescription,
              copyPayload: item.errorCopyPayload,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: color.withValues(alpha: 0.08),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final DownloadQueueStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, icon) = switch (status) {
      DownloadQueueStatus.downloading => (Colors.blue, Icons.download_rounded),
      DownloadQueueStatus.paused => (Colors.amber, Icons.pause_rounded),
      DownloadQueueStatus.queued ||
      DownloadQueueStatus.preparing =>
        (theme.colorScheme.primary, Icons.hourglass_top_rounded),
      _ => (theme.colorScheme.outline, Icons.more_horiz_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _fmt(int bytes) {
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
