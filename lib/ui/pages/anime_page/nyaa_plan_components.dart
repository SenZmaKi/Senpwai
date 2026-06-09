import 'package:flutter/material.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/ui/pages/anime_page/anime_source_ui.dart';
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

// ── PlanSectionHeader ─────────────────────────────────────────────────────────

class PlanSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int? count;
  final Color? color;

  const PlanSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.count,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurface.withValues(alpha: 0.7);
    return Row(
      children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: c,
            letterSpacing: 0.2,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: c,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(width: 12),
        Expanded(
          child: Divider(height: 1, color: c.withValues(alpha: 0.15)),
        ),
      ],
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

// ── PlanJobTile ───────────────────────────────────────────────────────────────

class PlanJobTile extends StatelessWidget {
  final PreparedDownloadJob job;

  const PlanJobTile({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;
    final torrentJob =
        job is PreparedTorrentDownloadJob
            ? job as PreparedTorrentDownloadJob
            : null;
    final meta = torrentJob?.reviewMetadata;
    final sourceColor = job.source.color;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ext.cardRadius),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        border: Border.all(
          color: ext.cardBorderColor,
          width: ext.cardBorderWidth,
        ),
        boxShadow: ext.cardShadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 4, color: sourceColor.withValues(alpha: 0.85)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: Image.asset(
                            job.source.iconAsset,
                            errorBuilder:
                                (_, _, _) => Icon(
                                  Icons.download_rounded,
                                  size: 14,
                                  color: sourceColor,
                                ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          job.source.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: sourceColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      torrentJob?.torrentName ?? job.displayTitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (meta?.isBatch ?? false)
                          const MetaBadge(
                            icon: Icons.collections_bookmark_rounded,
                            label: 'Batch',
                            color: Color(0xFF8B5CF6),
                          )
                        else if (meta?.episodeNumber != null)
                          MetaBadge(
                            icon: Icons.play_circle_outline_rounded,
                            label: 'Ep ${meta!.episodeNumber}',
                          ),
                        if (meta?.resolution != null)
                          MetaBadge(
                            icon: Icons.hd_rounded,
                            label: meta!.resolution.toString(),
                            color: qualityColor(meta.resolution),
                          ),
                        if (meta?.languageLabel != null)
                          MetaBadge(
                            icon: Icons.language_rounded,
                            label: meta!.languageLabel!,
                          ),
                        if (meta?.seeders != null)
                          MetaBadge(
                            icon: Icons.upload_rounded,
                            label: '${meta!.seeders} seeders',
                            color: seederColor(meta.seeders!),
                          ),
                        MetaBadge(
                          icon: Icons.save_alt_rounded,
                          label: planFormatBytes(job.totalBytes),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
