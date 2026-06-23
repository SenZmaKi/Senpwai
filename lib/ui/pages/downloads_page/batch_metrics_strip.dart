import 'package:flutter/material.dart';
import 'package:senpwai/ui/pages/downloads_page/download_batch_snapshot.dart';
import 'package:senpwai/ui/pages/downloads_page/download_formatters.dart';
import 'package:senpwai/ui/pages/downloads_page/download_status_style.dart';
import 'package:senpwai/ui/shared/responsive.dart';

/// Compact horizontal strip of labelled metrics under the batch progress bar.
class BatchMetricsStrip extends StatelessWidget {
  final DownloadBatchSnapshot snapshot;
  final DownloadStatusStyle style;
  const BatchMetricsStrip({
    super.key,
    required this.snapshot,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final speed = snapshot.bytesPerSecond > 0
        ? formatDownloadSpeed(snapshot.bytesPerSecond)
        : '—';
    final eta = snapshot.etaSeconds != null
        ? formatEtaSeconds(snapshot.etaSeconds!)
        : '—';
    final showTorrent = snapshot.hasTorrentStats;
    final upSpeed = showTorrent && snapshot.uploadBytesPerSecond > 0
        ? formatDownloadSpeed(snapshot.uploadBytesPerSecond)
        : '—';
    final mobile = isMobile(context);
    return Wrap(
      spacing: mobile ? 12 : 18,
      runSpacing: mobile ? 4 : 6,
      children: [
        _Metric(
          icon: Icons.download_rounded,
          label: showTorrent ? 'Down' : 'Speed',
          value: speed,
          color: style.color,
        ),
        if (showTorrent)
          _Metric(
            icon: Icons.upload_rounded,
            label: 'Up',
            value: upSpeed,
            color: theme.colorScheme.tertiary,
          ),
        if (showTorrent)
          _Metric(
            icon: Icons.cloud_done_rounded,
            label: 'Seeds',
            value: '${snapshot.numSeeds}',
            color: theme.colorScheme.primary,
          ),
        if (showTorrent)
          _Metric(
            icon: Icons.people_alt_rounded,
            label: 'Peers',
            value: '${snapshot.numPeers}',
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        _Metric(
          icon: Icons.timer_outlined,
          label: 'ETA',
          value: eta,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        _Metric(
          icon: Icons.check_circle_outline_rounded,
          label: 'Done',
          value: '${snapshot.completedCount}/${snapshot.items.length}',
          color: theme.colorScheme.secondary,
        ),
        if (snapshot.failedCount > 0)
          _Metric(
            icon: Icons.error_outline_rounded,
            label: 'Failed',
            value: '${snapshot.failedCount}',
            color: theme.colorScheme.error,
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
