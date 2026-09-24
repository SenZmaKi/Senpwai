import 'package:flutter/material.dart';
import 'package:senpwai/ui/shared/responsive.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

/// Ordinal index badge with status-themed background and border.
class DownloadOrdinalBadge extends StatelessWidget {
  final int position;
  final Color color;
  final double? size;

  const DownloadOrdinalBadge({
    super.key,
    required this.position,
    required this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final senpwai = theme.extension<SenpwaiThemeExtension>();
    final radius = (senpwai?.cardRadius ?? 4).clamp(0, 8).toDouble();
    final effectiveSize = size ?? (isMobile(context) ? 22.0 : 26.0);

    return Container(
      width: effectiveSize,
      height: effectiveSize,
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
          fontSize: effectiveSize < 24 ? 10 : 11,
        ),
      ),
    );
  }
}

/// Compact key-value metric item with icon and tabular figures.
class DownloadMetricTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final bool emphasize;
  final Color? tint;
  final String? tooltip;

  const DownloadMetricTile({
    super.key,
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
          style:
              (mobile
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

/// Interactive icon button with pointer cursor for accessibility.
class DownloadActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback onTap;
  final double size;

  const DownloadActionIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.size = 34,
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
        icon: Icon(icon, size: size * 0.52),
        style: IconButton.styleFrom(
          foregroundColor: tint,
          minimumSize: Size(size, size),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
