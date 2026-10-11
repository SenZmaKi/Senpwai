part of 'batch_item_row.dart';

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
    final needsRetry =
        item.status == DownloadQueueStatus.needsAction ||
        item.status == DownloadQueueStatus.failed;
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
        if (needsRetry)
          DownloadActionIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Retry download',
            color: theme.colorScheme.primary,
            onTap: () => notifier.resume(item.id),
          ),
        if (item.status == DownloadQueueStatus.recovering ||
            item.status == DownloadQueueStatus.waiting ||
            item.status == DownloadQueueStatus.queued)
          DownloadActionIconButton(
            icon: Icons.pause_rounded,
            tooltip: 'Pause download',
            color: theme.colorScheme.primary,
            onTap: () => notifier.pause(item.id),
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
        if (item.errorDescription != null)
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
