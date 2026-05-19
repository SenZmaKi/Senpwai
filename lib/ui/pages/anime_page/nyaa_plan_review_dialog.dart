import 'package:flutter/material.dart';
import 'package:senpwai/downloads/models.dart';

class NyaaPlanReviewDialog extends StatelessWidget {
  final PreparedDownloadBatch batch;

  const NyaaPlanReviewDialog({super.key, required this.batch});

  static Future<bool> confirm(
    BuildContext context, {
    required PreparedDownloadBatch batch,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => NyaaPlanReviewDialog(batch: batch),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Review Nyaa plan'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This is the automatic torrent plan that will be queued.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              for (final job in batch.jobs) ...[
                _PlanJobTile(job: job),
                const SizedBox(height: 10),
              ],
              if (batch.notices.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Notes',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final notice in batch.notices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• ${notice.title}${notice.description == null ? '' : ': ${notice.description}'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Queue downloads'),
        ),
      ],
    );
  }
}

class _PlanJobTile extends StatelessWidget {
  final PreparedDownloadJob job;

  const _PlanJobTile({required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final torrentJob = job is PreparedTorrentDownloadJob
        ? job as PreparedTorrentDownloadJob
        : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.displayTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${job.source.label} • ${_formatBytes(job.totalBytes)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          if (torrentJob != null) ...[
            const SizedBox(height: 8),
            Text(
              torrentJob.selectedFilePaths.join('\n'),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ],
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
