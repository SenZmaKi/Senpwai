import 'package:flutter/material.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_review/torrent_meta_row.dart';
import 'package:senpwai/ui/shared/theme/theme_extension.dart';

class TorrentCandidateTile extends StatelessWidget {
  final NyaaManualSearchCandidate candidate;
  final bool isSelecting;
  final bool isCurrentlySelected;
  final VoidCallback onSelect;

  const TorrentCandidateTile({
    super.key,
    required this.candidate,
    required this.isSelecting,
    required this.isCurrentlySelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;
    final accent = isCurrentlySelected
        ? Colors.green
        : theme.colorScheme.outline.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ext.cardRadius),
        color: isCurrentlySelected
            ? Colors.green.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
        border: Border.all(
          color: isCurrentlySelected
              ? Colors.green.withValues(alpha: 0.4)
              : accent,
          width: isCurrentlySelected ? 1.2 : ext.cardBorderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCurrentlySelected) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 1, right: 6),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: Colors.green,
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  candidate.result.filename,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TorrentMetaRow(
            data: TorrentMetaData.fromCandidate(candidate),
            showDate: true,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: isSelecting || isCurrentlySelected ? null : onSelect,
              icon: isSelecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isCurrentlySelected
                          ? Icons.check_rounded
                          : Icons.swap_horiz_rounded,
                    ),
              label: Text(isCurrentlySelected ? 'Selected' : 'Use this'),
            ),
          ),
        ],
      ),
    );
  }
}
