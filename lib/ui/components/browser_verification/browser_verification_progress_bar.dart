import 'package:flutter/material.dart';
import 'package:senpwai/ui/components/pulsing_progress_bar.dart';
import 'package:senpwai/ui/shared/theme/theme_extension.dart';

/// Theme-coherent progress bar for browser verification matching the download
/// page aesthetic with a theme-agnostic white/neutral energy sweep.
class BrowserVerificationProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;

  const BrowserVerificationProgressBar({
    super.key,
    required this.progress,
    this.height = 3.5,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final senpwai = theme.extension<SenpwaiThemeExtension>();
    final isComplete = progress >= 1.0;

    final primaryColor = theme.colorScheme.primary;
    final trackColor =
        senpwai?.downloadColors.progressTrack ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final pulseColor =
        senpwai?.downloadColors.pulseHighlight ??
        (theme.brightness == Brightness.dark
            ? const Color(0x44FFFFFF)
            : const Color(0x33000000));

    return AnimatedOpacity(
      opacity: isComplete ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
      child: PulsingProgressBar(
        value: progress.clamp(0.0, 1.0),
        height: height,
        color: primaryColor,
        trackColor: trackColor,
        pulseColor: pulseColor,
        pulsing: !isComplete,
        borderRadius: BorderRadius.zero,
        semanticsLabel: 'Verification page loading progress',
        semanticsValue: '${(progress.clamp(0.0, 1.0) * 100).toInt()}%',
      ),
    );
  }
}
