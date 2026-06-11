import 'package:flutter/material.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/ui/shared/theme/theme_extension.dart';

// ── Color helpers ─────────────────────────────────────────────────────────────

Color qualityColor(Resolution? resolution) => switch (resolution) {
  Resolution.res4320p || Resolution.res2160p => const Color(0xFF9B59B6),
  Resolution.res1440p || Resolution.res1080p => const Color(0xFFF59E0B),
  Resolution.res720p => const Color(0xFF3B82F6),
  Resolution.res480p => const Color(0xFFEA580C),
  _ => const Color(0xFF6B7280),
};

Color seederColor(int seeders) {
  if (seeders >= 20) return Colors.green;
  if (seeders >= 5) return const Color(0xFFD97706);
  return Colors.red;
}

String planFormatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}

// ── PlanStatPill ──────────────────────────────────────────────────────────────

class PlanStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const PlanStatPill({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;
    final c = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ext.cardRadius),
        color: c.withValues(alpha: 0.12),
        border: Border.all(
          color: c.withValues(alpha: 0.28),
          width: ext.cardBorderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: c,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── MetaBadge ─────────────────────────────────────────────────────────────────

class MetaBadge extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? color;

  const MetaBadge({super.key, this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;
    final c = color;
    final radius = ext.cardRadius.clamp(0.0, 8.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: c != null
            ? c.withValues(alpha: 0.14)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        border: c != null
            ? Border.all(color: c.withValues(alpha: 0.3), width: 0.8)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: c ?? theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: c ?? theme.colorScheme.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
