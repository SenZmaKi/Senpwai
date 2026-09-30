import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/shared/platform_file_opener.dart';
import 'package:senpwai/ui/components/confirm_dialog.dart';
import 'package:senpwai/ui/components/pulsing_progress_bar.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/pages/downloads_page/download_formatters.dart';
import 'package:senpwai/ui/pages/downloads_page/download_item_widgets.dart';
import 'package:senpwai/ui/pages/downloads_page/download_status_style.dart';
import 'package:senpwai/ui/pages/downloads_page/torrent_file_rows.dart';
import 'package:senpwai/ui/shared/responsive.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

/// A single download row inside the active batch view.
///
/// Visually distinct from the batch wrapper card: thinner, denser,
/// uses surfaceContainerHighest as base, leading status dot, trailing
/// pause/resume + cancel controls. Theme-driven throughout.
class BatchItemRow extends ConsumerWidget {
  final DownloadQueueItem item;
  final int position;

  const BatchItemRow({super.key, required this.item, required this.position});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final senpwai = theme.extension<SenpwaiThemeExtension>();
    final style = DownloadStatusStyle.of(theme, item.status);
    final radius = (senpwai?.cardRadius ?? 8) * 0.75;
    final mobile = isMobile(context);

    return Container(
      padding: mobile
          ? const EdgeInsets.fromLTRB(12, 10, 8, 10)
          : const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: item.status.isTerminal
              ? theme.colorScheme.outline.withValues(alpha: 0.12)
              : style.color.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Heading(item: item, position: position, style: style),
          SizedBox(height: mobile ? 8 : 10),
          _ProgressLine(item: item, style: style),
          SizedBox(height: mobile ? 6 : 8),
          _MetricsAndControls(item: item),
          if (item.torrentFiles.length > 1) ...[
            SizedBox(height: mobile ? 10 : 12),
            TorrentFileRows(item: item),
          ],
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final DownloadQueueItem item;
  final int position;
  final DownloadStatusStyle style;

  const _Heading({
    required this.item,
    required this.position,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mobile = isMobile(context);
    final fileCount = item.torrentFiles.length;
    final subtitle = fileCount > 1
        ? '${item.source.label}  ·  $fileCount files'
        : item.source.label;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DownloadOrdinalBadge(position: position, color: style.color),
        SizedBox(width: mobile ? 8 : 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDownloadTitle(item.displayTitle),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (mobile
                            ? theme.textTheme.bodySmall
                            : theme.textTheme.bodyMedium)
                        ?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final DownloadQueueItem item;
  final DownloadStatusStyle style;
  const _ProgressLine({required this.item, required this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final senpwai = theme.extension<SenpwaiThemeExtension>()!;
    final palette = senpwai.downloadColors;
    final isIndeterminate =
        item.status == DownloadQueueStatus.queued ||
        item.status == DownloadQueueStatus.preparing;
    final barRadius = (senpwai.cardRadius * 0.5).clamp(0, 6).toDouble();

    return PulsingProgressBar(
      value: isIndeterminate ? null : item.progress.clamp(0.0, 1.0),
      height: 6,
      color: style.color,
      trackColor: palette.progressTrack,
      pulseColor: palette.pulseHighlight,
      pulsing:
          item.status == DownloadQueueStatus.downloading ||
          item.status == DownloadQueueStatus.seeding ||
          isIndeterminate,
      borderRadius: BorderRadius.circular(barRadius),
    );
  }
}

class _MetricsAndControls extends ConsumerWidget {
  final DownloadQueueItem item;
  const _MetricsAndControls({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(DownloadManagerNotifier.provider.notifier);
    final pct = (item.progress.clamp(0.0, 1.0) * 100).toStringAsFixed(1);
    final isDownloading = item.status == DownloadQueueStatus.downloading;
    final isSeeding = item.isSeedingPhase;
    final isPaused = item.status == DownloadQueueStatus.paused;
    final showLive = isDownloading && item.bytesPerSecond > 0;
    final speed = showLive ? formatDownloadSpeed(item.bytesPerSecond) : '—';
    final eta = showLive ? formatDownloadEta(item) : '—';
    final torrent = item.torrentStats;
    final showTorrentLive = torrent != null && !item.status.isTerminal;
    final upSpeed = showTorrentLive && torrent.uploadBytesPerSecond > 0
        ? formatDownloadSpeed(torrent.uploadBytesPerSecond)
        : '—';
    final canOpenFile =
        (item.status == DownloadQueueStatus.completed || item.isSeedingPhase) &&
        item.filePaths.isNotEmpty;

    final mobile = isMobile(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            spacing: mobile ? 10 : 14,
            runSpacing: mobile ? 4 : 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DownloadMetricTile(
                icon: Icons.percent_rounded,
                value: pct,
                emphasize: true,
              ),
              DownloadMetricTile(
                icon: Icons.sd_storage_outlined,
                value:
                    '${formatDownloadBytes(item.downloadedBytes)} / ${formatDownloadBytes(item.totalBytes)}',
              ),
              DownloadMetricTile(
                icon: Icons.download_rounded,
                value: speed,
                tint: showLive ? theme.colorScheme.primary : null,
              ),
              if (showTorrentLive)
                DownloadMetricTile(
                  icon: Icons.upload_rounded,
                  value: upSpeed,
                  tint: torrent.uploadBytesPerSecond > 0
                      ? theme.colorScheme.tertiary
                      : null,
                ),
              if (showTorrentLive)
                DownloadMetricTile(
                  icon: Icons.cloud_done_rounded,
                  value: torrent.listSeeds > 0
                      ? '${torrent.numSeeds}/${torrent.listSeeds}'
                      : '${torrent.numSeeds}',
                  tooltip: 'Connected seeds / swarm seeds',
                ),
              if (showTorrentLive)
                DownloadMetricTile(
                  icon: Icons.people_alt_rounded,
                  value: torrent.listPeers > 0
                      ? '${torrent.numPeers}/${torrent.listPeers}'
                      : '${torrent.numPeers}',
                  tooltip: 'Connected peers / swarm peers',
                ),
              DownloadMetricTile(icon: Icons.timer_outlined, value: eta),
            ],
          ),
        ),
        if (canOpenFile)
          DownloadActionIconButton(
            icon: Icons.open_in_new_rounded,
            tooltip: 'Open downloaded file',
            color: theme.colorScheme.primary,
            onTap: () async {
              final error = await PlatformFileOpener.openFile(
                item.filePaths.first,
              );
              if (error != null && context.mounted) {
                AppToast.showError(
                  context,
                  title: 'Could not open file',
                  description: error,
                );
              }
            },
          ),
        if (isDownloading || isSeeding)
          DownloadActionIconButton(
            icon: Icons.pause_rounded,
            tooltip: 'Pause',
            onTap: () => notifier.pause(item.id),
          ),
        if (isPaused)
          DownloadActionIconButton(
            icon: Icons.play_arrow_rounded,
            tooltip: 'Resume',
            color: theme.colorScheme.primary,
            onTap: () => notifier.resume(item.id),
          ),
        if (!item.status.isTerminal)
          DownloadActionIconButton(
            icon: Icons.close_rounded,
            tooltip: isSeeding ? 'Stop seeding' : 'Cancel',
            color: theme.colorScheme.error.withValues(alpha: 0.75),
            onTap: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: isSeeding ? 'Stop seeding?' : 'Cancel this download?',
                message: isSeeding
                    ? 'This will stop sharing "${formatDownloadTitle(item.displayTitle)}". The '
                          'downloaded files will not be deleted.'
                    : 'This will stop "${formatDownloadTitle(item.displayTitle)}" and discard its '
                          'remaining download progress.',
                confirmLabel: isSeeding ? 'Stop seeding' : 'Cancel download',
                cancelLabel: isSeeding ? 'Keep seeding' : 'Keep downloading',
                destructive: !isSeeding,
              );
              if (confirmed) notifier.cancel(item.id);
            },
          ),
        if (item.errorCopyPayload != null)
          DownloadActionIconButton(
            icon: Icons.bug_report_rounded,
            tooltip: 'Show error',
            color: theme.colorScheme.error.withValues(alpha: 0.75),
            onTap: () => AppToast.showError(
              context,
              title: item.errorTitle ?? 'Download failed',
              description: item.errorDescription,
              copyPayload: item.errorCopyPayload,
            ),
          ),
        if (item.status.isTerminal &&
            item.status != DownloadQueueStatus.completed)
          DownloadActionIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Dismiss',
            color: theme.colorScheme.outline,
            onTap: () => notifier.dismiss(item.id),
          ),
      ],
    );
  }
}
