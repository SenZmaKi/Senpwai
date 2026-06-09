import 'package:flutter/material.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/ui/pages/downloads_page/download_batch_snapshot.dart';
import 'package:senpwai/ui/pages/downloads_page/download_formatters.dart';
import 'package:senpwai/ui/pages/downloads_page/download_status_style.dart';
import 'package:senpwai/ui/pages/downloads_page/pulsing_progress_bar.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

/// Hero progress bar for the active batch panel.
/// Big percentage on the left, byte counts on the right, tall solid bar.
class BatchBigProgressBar extends StatelessWidget {
  final DownloadBatchSnapshot snapshot;
  final DownloadStatusStyle style;
  const BatchBigProgressBar({
    super.key,
    required this.snapshot,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = snapshot.progress.clamp(0.0, 1.0);
    final pct = (progress * 100).toStringAsFixed(1);
    final indeterminate = snapshot.status == DownloadQueueStatus.queued;
    final senpwai = theme.extension<SenpwaiThemeExtension>()!;
    final palette = senpwai.downloadColors;
    final track = palette.progressTrack;
    final barRadius = (senpwai.cardRadius * 0.5).clamp(0, 12).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              pct,
              style: theme.textTheme.displaySmall?.copyWith(
                color: style.color,
                fontWeight: FontWeight.w900,
                height: 0.95,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: style.color.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '${formatDownloadBytes(snapshot.downloadedBytes)}  /  '
              '${formatDownloadBytes(snapshot.totalBytes)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PulsingProgressBar(
          value: indeterminate ? null : progress,
          height: 18,
          color: style.color,
          trackColor: track,
          pulseColor: palette.pulseHighlight,
          pulsing: snapshot.status == DownloadQueueStatus.downloading ||
              snapshot.status == DownloadQueueStatus.queued,
          borderRadius: BorderRadius.circular(barRadius),
        ),
      ],
    );
  }
}
