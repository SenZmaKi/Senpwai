import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/shared/platform_file_opener.dart';
import 'package:senpwai/ui/components/pulsing_progress_bar.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/pages/downloads_page/download_formatters.dart';
import 'package:senpwai/ui/pages/downloads_page/download_item_widgets.dart';
import 'package:senpwai/ui/pages/downloads_page/download_status_style.dart';
import 'package:senpwai/ui/shared/responsive.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

/// Container displaying all individual files inside a multi-file torrent,
/// visually aligned with the standard downloads UI.
class TorrentFileRows extends StatelessWidget {
  final DownloadQueueItem item;

  const TorrentFileRows({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mobile = isMobile(context);
    final files = item.torrentFiles;
    final completedCount = files.where((f) => f.isComplete).length;

    return Container(
      padding: mobile
          ? const EdgeInsets.fromLTRB(10, 10, 10, 10)
          : const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.22,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            totalCount: files.length,
            completedCount: completedCount,
          ),
          SizedBox(height: mobile ? 8 : 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: files.length,
            separatorBuilder: (_, __) => SizedBox(height: mobile ? 6 : 8),
            itemBuilder: (context, index) {
              return _TorrentFileCard(
                file: files[index],
                position: index + 1,
                parentStatus: item.status,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final int totalCount;
  final int completedCount;

  const _SectionHeader({
    required this.totalCount,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 14,
          height: 2,
          color: theme.colorScheme.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 8),
        Text(
          'TORRENT FILES',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '·  $completedCount / $totalCount completed',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TorrentFileCard extends StatelessWidget {
  final TorrentFileProgress file;
  final int position;
  final DownloadQueueStatus parentStatus;

  const _TorrentFileCard({
    required this.file,
    required this.position,
    required this.parentStatus,
  });

  DownloadQueueStatus get _status {
    if (file.isComplete) return DownloadQueueStatus.completed;
    if (parentStatus == DownloadQueueStatus.failed) {
      return DownloadQueueStatus.failed;
    }
    if (parentStatus == DownloadQueueStatus.paused) {
      return DownloadQueueStatus.paused;
    }
    if (parentStatus == DownloadQueueStatus.cancelled) {
      return DownloadQueueStatus.cancelled;
    }
    if (file.isActive &&
        (parentStatus == DownloadQueueStatus.downloading ||
            parentStatus == DownloadQueueStatus.seeding)) {
      return DownloadQueueStatus.downloading;
    }
    if (parentStatus == DownloadQueueStatus.seeding && file.isComplete) {
      return DownloadQueueStatus.seeding;
    }
    return DownloadQueueStatus.queued;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final senpwai = theme.extension<SenpwaiThemeExtension>();
    final status = _status;
    final style = DownloadStatusStyle.of(theme, status);
    final palette = senpwai?.downloadColors;
    final mobile = isMobile(context);
    final radius = ((senpwai?.cardRadius ?? 8) * 0.65).clamp(4.0, 10.0);
    final percent = (file.progress.clamp(0.0, 1.0) * 100).toStringAsFixed(1);
    final isPulsing =
        file.isActive &&
        (parentStatus == DownloadQueueStatus.downloading ||
            parentStatus == DownloadQueueStatus.seeding);

    return Container(
      padding: mobile
          ? const EdgeInsets.fromLTRB(10, 8, 8, 8)
          : const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: file.isComplete
              ? theme.colorScheme.outline.withValues(alpha: 0.12)
              : style.color.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DownloadOrdinalBadge(
                position: position,
                color: style.color,
                size: mobile ? 22 : 24,
              ),
              SizedBox(width: mobile ? 8 : 10),
              Expanded(
                child: Text(
                  formatDownloadTitle(path.basename(file.path)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (mobile
                              ? theme.textTheme.bodySmall
                              : theme.textTheme.bodyMedium)
                          ?.copyWith(
                            fontWeight: file.isActive || file.isComplete
                                ? FontWeight.w700
                                : FontWeight.w600,
                            height: 1.2,
                          ),
                ),
              ),
              const SizedBox(width: 8),
              DownloadStatusChip(status: status, compact: true),
            ],
          ),
          SizedBox(height: mobile ? 6 : 8),
          if (palette != null)
            PulsingProgressBar(
              value: file.progress.clamp(0.0, 1.0),
              height: 5,
              color: style.color,
              trackColor: palette.progressTrack,
              pulseColor: palette.pulseHighlight,
              pulsing: isPulsing,
              borderRadius: BorderRadius.circular(
                ((senpwai?.cardRadius ?? 4) * 0.4).clamp(0, 4).toDouble(),
              ),
            ),
          SizedBox(height: mobile ? 6 : 8),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: mobile ? 10 : 14,
                  runSpacing: mobile ? 4 : 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DownloadMetricTile(
                      icon: Icons.percent_rounded,
                      value: percent,
                      emphasize: true,
                    ),
                    DownloadMetricTile(
                      icon: Icons.sd_storage_outlined,
                      value:
                          '${formatDownloadBytes(file.downloadedBytes)} / ${formatDownloadBytes(file.totalBytes)}',
                    ),
                  ],
                ),
              ),
              if (file.isComplete && file.path.isNotEmpty)
                DownloadActionIconButton(
                  icon: Icons.open_in_new_rounded,
                  tooltip: 'Open downloaded file',
                  color: theme.colorScheme.primary,
                  size: mobile ? 28 : 32,
                  onTap: () async {
                    final error = await PlatformFileOpener.openFile(file.path);
                    if (error != null && context.mounted) {
                      AppToast.showError(
                        context,
                        title: 'Could not open file',
                        description: error,
                      );
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
