import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/ui/components/confirm_dialog.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/pages/downloads_page/download_formatters.dart';
import 'package:senpwai/ui/pages/downloads_page/download_status_style.dart';
import 'package:senpwai/ui/pages/downloads_page/pulsing_progress_bar.dart';
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
          ? const EdgeInsets.fromLTRB(12, 10, 6, 10)
          : const EdgeInsets.fromLTRB(14, 12, 8, 12),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _OrdinalBadge(position: position, color: style.color),
        SizedBox(width: mobile ? 8 : 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (mobile
                        ? theme.textTheme.bodySmall
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
              ),
              const SizedBox(height: 2),
              Text(
                item.source.label,
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

class _OrdinalBadge extends StatelessWidget {
  final int position;
  final Color color;
  const _OrdinalBadge({required this.position, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final senpwai = theme.extension<SenpwaiThemeExtension>();
    final radius = (senpwai?.cardRadius ?? 4).clamp(0, 8).toDouble();
    final size = isMobile(context) ? 22.0 : 26.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$position',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
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
          item.status == DownloadQueueStatus.downloading || isIndeterminate,
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
    final isPaused = item.status == DownloadQueueStatus.paused;
    final showLive = isDownloading && item.bytesPerSecond > 0;
    final speed = showLive ? formatDownloadSpeed(item.bytesPerSecond) : '—';
    final eta = showLive ? formatDownloadEta(item) : '—';
    final torrent = item.torrentStats;
    final showTorrentLive = torrent != null && !item.status.isTerminal;
    final upSpeed = showTorrentLive && torrent.uploadBytesPerSecond > 0
        ? formatDownloadSpeed(torrent.uploadBytesPerSecond)
        : '—';

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
              _Tile(icon: Icons.percent_rounded, value: pct, emphasize: true),
              _Tile(
                icon: Icons.sd_storage_outlined,
                value:
                    '${formatDownloadBytes(item.downloadedBytes)} / ${formatDownloadBytes(item.totalBytes)}',
              ),
              _Tile(
                icon: Icons.download_rounded,
                value: speed,
                tint: showLive ? theme.colorScheme.primary : null,
              ),
              if (showTorrentLive)
                _Tile(
                  icon: Icons.upload_rounded,
                  value: upSpeed,
                  tint: torrent.uploadBytesPerSecond > 0
                      ? theme.colorScheme.tertiary
                      : null,
                ),
              if (showTorrentLive)
                _Tile(
                  icon: Icons.cloud_done_rounded,
                  value: torrent.listSeeds > 0
                      ? '${torrent.numSeeds}/${torrent.listSeeds}'
                      : '${torrent.numSeeds}',
                  tooltip: 'Connected seeds / swarm seeds',
                ),
              if (showTorrentLive)
                _Tile(
                  icon: Icons.people_alt_rounded,
                  value: torrent.listPeers > 0
                      ? '${torrent.numPeers}/${torrent.listPeers}'
                      : '${torrent.numPeers}',
                  tooltip: 'Connected peers / swarm peers',
                ),
              _Tile(icon: Icons.timer_outlined, value: eta),
            ],
          ),
        ),
        if (isDownloading)
          _IconAction(
            icon: Icons.pause_rounded,
            tooltip: 'Pause',
            onTap: () => notifier.pause(item.id),
          ),
        if (isPaused)
          _IconAction(
            icon: Icons.play_arrow_rounded,
            tooltip: 'Resume',
            color: theme.colorScheme.primary,
            onTap: () => notifier.resume(item.id),
          ),
        if (!item.status.isTerminal)
          _IconAction(
            icon: Icons.close_rounded,
            tooltip: 'Cancel',
            color: theme.colorScheme.error.withValues(alpha: 0.75),
            onTap: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Cancel this download?',
                message:
                    'This will stop "${item.displayTitle}" and discard its '
                    'remaining download progress.',
                confirmLabel: 'Cancel download',
                cancelLabel: 'Keep downloading',
                destructive: true,
              );
              if (confirmed) notifier.cancel(item.id);
            },
          ),
        if (item.errorCopyPayload != null)
          _IconAction(
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
          _IconAction(
            icon: Icons.close_rounded,
            tooltip: 'Dismiss',
            color: theme.colorScheme.outline,
            onTap: () => notifier.dismiss(item.id),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String value;
  final bool emphasize;
  final Color? tint;
  final String? tooltip;
  const _Tile({
    required this.icon,
    required this.value,
    this.emphasize = false,
    this.tint,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mobile = isMobile(context);
    final color =
        tint ??
        (emphasize
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurface.withValues(alpha: 0.65));
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: mobile ? 11 : 13,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
        ),
        SizedBox(width: mobile ? 3 : 4),
        Text(
          emphasize ? '$value%' : value,
          style: (mobile
                  ? theme.textTheme.labelSmall
                  : theme.textTheme.labelMedium)
              ?.copyWith(
            color: color,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
    if (tooltip == null) return row;
    return Tooltip(message: tooltip!, child: row);
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurface.withValues(alpha: 0.7);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          foregroundColor: tint,
          minimumSize: const Size(34, 34),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
