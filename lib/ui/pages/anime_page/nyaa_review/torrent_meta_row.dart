import 'package:flutter/material.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_plan_components.dart';

/// View-model for the metadata row badges. Single source of truth shared by
/// candidate tiles (in the picker view) and episode review rows (in the sheet).
class TorrentMetaData {
  final int? episodeNumber;
  final bool isBatch;
  final Resolution? resolution;
  final String? languageLabel;
  final int? seeders;
  final int? sizeBytes;
  final DateTime? dateAdded;

  /// True when the candidate's parsed episode matches the requested episode.
  /// Drives the green-check badge in candidate tiles. Null when not relevant
  /// (e.g. rendering an already-resolved job).
  final bool? matchesRequestedEpisode;

  const TorrentMetaData({
    this.episodeNumber,
    this.isBatch = false,
    this.resolution,
    this.languageLabel,
    this.seeders,
    this.sizeBytes,
    this.dateAdded,
    this.matchesRequestedEpisode,
  });

  factory TorrentMetaData.fromCandidate(NyaaManualSearchCandidate c) {
    return TorrentMetaData(
      episodeNumber: c.parsedEpisodeNumber,
      isBatch: c.isBatch,
      resolution: c.resolution,
      languageLabel: c.languageSignal.label,
      seeders: c.result.seeders,
      sizeBytes: c.result.sizeBytes,
      dateAdded: c.result.dateAdded,
      matchesRequestedEpisode: c.matchesRequestedEpisode,
    );
  }

  factory TorrentMetaData.fromJob(PreparedTorrentDownloadJob job) {
    final meta = job.reviewMetadata;
    return TorrentMetaData(
      episodeNumber: meta?.episodeNumber,
      isBatch: meta?.isBatch ?? false,
      resolution: meta?.resolution,
      languageLabel: meta?.languageLabel,
      seeders: meta?.seeders,
      sizeBytes: job.totalBytes,
    );
  }
}

class TorrentMetaRow extends StatelessWidget {
  final TorrentMetaData data;
  final bool showDate;

  /// Compact = smaller spacing, hides date even if available. Used for
  /// dense list rows.
  final bool compact;

  const TorrentMetaRow({
    super.key,
    required this.data,
    this.showDate = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final episodeMatch = data.matchesRequestedEpisode ?? false;
    final episodeBadgeColor = data.matchesRequestedEpisode == true
        ? theme.colorScheme.primary
        : null;

    final episodeLabel = data.isBatch
        ? 'Batch'
        : data.episodeNumber != null
        ? 'Ep ${data.episodeNumber}'
        : null;

    return Wrap(
      spacing: compact ? 4 : 6,
      runSpacing: compact ? 4 : 6,
      children: [
        if (data.isBatch)
          const MetaBadge(
            icon: Icons.collections_bookmark_rounded,
            label: 'Batch',
            color: Color(0xFF8B5CF6),
          )
        else if (episodeLabel != null)
          MetaBadge(
            icon: data.matchesRequestedEpisode == true
                ? Icons.check_rounded
                : Icons.play_circle_outline_rounded,
            label: episodeLabel,
            color: episodeMatch ? episodeBadgeColor : null,
          ),
        if (data.resolution != null)
          MetaBadge(
            icon: Icons.hd_rounded,
            label: data.resolution!.toString(),
            color: qualityColor(data.resolution),
          ),
        if (data.languageLabel != null)
          MetaBadge(icon: Icons.language_rounded, label: data.languageLabel!),
        if (data.seeders != null)
          MetaBadge(
            icon: Icons.upload_rounded,
            label: '${data.seeders} seeders',
            color: seederColor(data.seeders!),
          ),
        if (data.sizeBytes != null)
          MetaBadge(
            icon: Icons.save_alt_rounded,
            label: planFormatBytes(data.sizeBytes!),
          ),
        if (showDate && !compact && data.dateAdded != null)
          MetaBadge(
            icon: Icons.schedule_rounded,
            label: _formatDate(data.dateAdded!),
          ),
      ],
    );
  }
}

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inDays >= 365) {
    final years = (diff.inDays / 365).floor();
    return '${years}y ago';
  }
  if (diff.inDays >= 30) {
    final months = (diff.inDays / 30).floor();
    return '${months}mo ago';
  }
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
  return 'just now';
}
