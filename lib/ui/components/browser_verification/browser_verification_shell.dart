import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:senpwai/ui/components/browser_verification/browser_verification_progress_bar.dart';
import 'package:senpwai/ui/components/browser_verification/browser_verification_header.dart';
import 'package:senpwai/ui/shared/responsive.dart';
import 'package:senpwai/ui/shared/theme/theme_extension.dart';

/// Responsive shell container for the browser verification interface.
///
/// Presents an edge-to-edge modal sheet on mobile devices and a centered,
/// elevated window with frosted backdrop scrim on tablet/desktop displays.
class BrowserVerificationShell extends StatelessWidget {
  final String host;
  final Widget child;
  final double progress;
  final VoidCallback onReload;
  final VoidCallback onCancel;

  const BrowserVerificationShell({
    super.key,
    required this.host,
    required this.child,
    required this.progress,
    required this.onReload,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final theme = Theme.of(context);
    final senpwai = theme.extension<SenpwaiThemeExtension>();
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = mobile
        ? double.infinity
        : math.min(840.0, screenSize.width - 64.0);
    final dialogHeight = mobile
        ? double.infinity
        : math.min(740.0, screenSize.height - 72.0);
    final radius = math.max(12.0, senpwai?.cardRadius ?? 14.0);
    final borderRadius = mobile
        ? const BorderRadius.vertical(top: Radius.circular(20))
        : BorderRadius.circular(radius);

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () {}, // Prevent tap-through
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: mobile ? 0 : 5,
              sigmaY: mobile ? 0 : 5,
            ),
            child: Container(
              color: Colors.black.withValues(alpha: mobile ? 0.5 : 0.65),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          minimum: EdgeInsets.symmetric(
            horizontal: mobile ? 0 : 32,
            vertical: mobile ? 0 : 36,
          ),
          child: Center(
            child: Container(
              width: dialogWidth,
              height: dialogHeight,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: borderRadius,
                border: mobile
                    ? null
                    : Border.all(
                        color:
                            senpwai?.cardBorderColor ??
                            theme.colorScheme.primary.withValues(alpha: 0.3),
                        width: senpwai?.cardBorderWidth ?? 1.0,
                      ),
                boxShadow: mobile
                    ? null
                    : senpwai?.cardShadows ??
                          [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
              ),
              child: ClipRRect(
                borderRadius: borderRadius,
                child: Material(
                  color: theme.colorScheme.surface,
                  child: Column(
                    children: [
                      BrowserVerificationHeader(
                        host: host,
                        isMobile: mobile,
                        onReload: onReload,
                        onCancel: onCancel,
                      ),
                      BrowserVerificationProgressBar(progress: progress),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
