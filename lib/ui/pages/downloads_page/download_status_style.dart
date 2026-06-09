import 'package:flutter/material.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

/// Theme-driven visual treatment per download status.
/// Colors come from [SenpwaiThemeExtension.downloadColors] so each preset
/// can supply theme-coherent variants instead of leaning on raw scheme colors.
class DownloadStatusStyle {
  final Color color;
  final IconData icon;
  final String label;

  const DownloadStatusStyle({
    required this.color,
    required this.icon,
    required this.label,
  });

  factory DownloadStatusStyle.of(
    ThemeData theme,
    DownloadQueueStatus status,
  ) {
    final palette = theme.extension<SenpwaiThemeExtension>()!.downloadColors;
    return switch (status) {
      DownloadQueueStatus.downloading => DownloadStatusStyle(
        color: palette.downloading,
        icon: Icons.downloading_rounded,
        label: status.label,
      ),
      DownloadQueueStatus.paused => DownloadStatusStyle(
        color: palette.paused,
        icon: Icons.pause_circle_rounded,
        label: status.label,
      ),
      DownloadQueueStatus.queued => DownloadStatusStyle(
        color: palette.queued,
        icon: Icons.hourglass_empty_rounded,
        label: status.label,
      ),
      DownloadQueueStatus.preparing => DownloadStatusStyle(
        color: palette.downloading,
        icon: Icons.hourglass_top_rounded,
        label: status.label,
      ),
      DownloadQueueStatus.completed => DownloadStatusStyle(
        color: palette.completed,
        icon: Icons.check_circle_rounded,
        label: status.label,
      ),
      DownloadQueueStatus.failed => DownloadStatusStyle(
        color: palette.failed,
        icon: Icons.error_rounded,
        label: status.label,
      ),
      DownloadQueueStatus.cancelled => DownloadStatusStyle(
        color: palette.cancelled,
        icon: Icons.cancel_rounded,
        label: status.label,
      ),
    };
  }
}

/// Small pill chip showing icon + status label, recolored from theme.
class DownloadStatusChip extends StatelessWidget {
  final DownloadQueueStatus status;
  final bool compact;

  const DownloadStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = DownloadStatusStyle.of(theme, status);
    final senpwai = theme.extension<SenpwaiThemeExtension>();
    final padH = compact ? 8.0 : 10.0;
    final padV = compact ? 4.0 : 5.0;
    final iconSize = compact ? 12.0 : 14.0;
    final radius = (senpwai?.cardRadius ?? 4).clamp(0, 12).toDouble();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: style.color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: iconSize, color: style.color),
          const SizedBox(width: 5),
          Text(
            style.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: style.color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
