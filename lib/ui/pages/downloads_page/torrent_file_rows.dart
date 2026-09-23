import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/ui/pages/downloads_page/download_formatters.dart';

class TorrentFileRows extends StatelessWidget {
  final DownloadQueueItem item;

  const TorrentFileRows({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          for (var index = 0; index < item.torrentFiles.length; index++) ...[
            _TorrentFileRow(
              file: item.torrentFiles[index],
              position: index + 1,
              parentStatus: item.status,
            ),
            if (index != item.torrentFiles.length - 1)
              Divider(
                height: 1,
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
              ),
          ],
        ],
      ),
    );
  }
}

class _TorrentFileRow extends StatelessWidget {
  final TorrentFileProgress file;
  final int position;
  final DownloadQueueStatus parentStatus;

  const _TorrentFileRow({
    required this.file,
    required this.position,
    required this.parentStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _status;
    final color = switch (status) {
      _FileStatus.complete => theme.colorScheme.tertiary,
      _FileStatus.downloading => theme.colorScheme.primary,
      _FileStatus.paused => theme.colorScheme.secondary,
      _FileStatus.failed => theme.colorScheme.error,
      _FileStatus.queued => theme.colorScheme.onSurface.withValues(alpha: 0.38),
    };
    final percent = (file.progress * 100).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$position',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        path.basename(file.path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: file.isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${status.label} · $percent%',
                      style: theme.textTheme.labelSmall?.copyWith(color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: file.progress.clamp(0.0, 1.0),
                    minHeight: 3,
                    color: color,
                    backgroundColor: theme.colorScheme.outline.withValues(
                      alpha: 0.12,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatDownloadBytes(file.downloadedBytes)} / ${formatDownloadBytes(file.totalBytes)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _FileStatus get _status {
    if (file.isComplete) return _FileStatus.complete;
    if (parentStatus == DownloadQueueStatus.failed) return _FileStatus.failed;
    if (parentStatus == DownloadQueueStatus.paused) return _FileStatus.paused;
    if (file.isActive && parentStatus == DownloadQueueStatus.downloading) {
      return _FileStatus.downloading;
    }
    return _FileStatus.queued;
  }
}

enum _FileStatus {
  queued('Queued'),
  downloading('Downloading'),
  paused('Paused'),
  complete('Complete'),
  failed('Failed');

  final String label;
  const _FileStatus(this.label);
}
