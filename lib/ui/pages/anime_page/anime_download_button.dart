import 'package:flutter/material.dart';
import 'package:senpwai/downloads/anime_download_session.dart';
import 'package:senpwai/ui/components/pulsing_progress_bar.dart';

/// The primary download action button which seamlessly transforms into
/// a full-button progress bar with live shimmer during planning.
class AnimeDownloadButton extends StatelessWidget {
  final AnimeDownloadSessionState state;
  final bool canStartDownload;
  final bool canCancelPlanning;
  final VoidCallback onDownload;
  final VoidCallback onCancelPlanning;

  const AnimeDownloadButton({
    super.key,
    required this.state,
    required this.canStartDownload,
    required this.canCancelPlanning,
    required this.onDownload,
    required this.onCancelPlanning,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlanning =
        state.submissionStage == DownloadSubmissionStage.planning;

    // When planning, the entire button acts as a live progress bar.
    if (isPlanning && !state.planningCancellationRequested) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Progress fill & shimmer energy pulse layer
              Positioned.fill(
                child: PulsingProgressBar(
                  value: state.planningProgress?.fraction ?? 0.0,
                  height: 48,
                  color: theme.colorScheme.primary,
                  trackColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.6),
                  pulseColor: Colors.white.withValues(alpha: 0.35),
                  pulsing: true,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // Foreground label & cancel trigger
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onCancelPlanning,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            state.submitButtonLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black45,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final canPress = canStartDownload || canCancelPlanning;

    return MouseRegion(
      cursor: canPress ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: ElevatedButton.icon(
        onPressed: canCancelPlanning
            ? onCancelPlanning
            : canStartDownload
            ? onDownload
            : null,
        icon: state.isSubmittingDownload
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_rounded, size: 20),
        label: Text(
          state.submitButtonLabel,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canPress
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: canPress
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: canStartDownload ? 2 : 0,
        ),
      ),
    );
  }
}
