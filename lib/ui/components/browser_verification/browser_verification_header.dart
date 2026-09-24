import 'package:flutter/material.dart';

/// Top header shell for browser verification dialog/sheet.
///
/// Features mobile grab handle, security badge, verified host pill,
/// action controls (reload, cancel), and reassurance context banner.
class BrowserVerificationHeader extends StatelessWidget {
  final String host;
  final bool isMobile;
  final VoidCallback onReload;
  final VoidCallback onCancel;

  const BrowserVerificationHeader({
    super.key,
    required this.host,
    required this.isMobile,
    required this.onReload,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMobile) const _GrabHandle(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 20,
              isMobile ? 8 : 14,
              isMobile ? 12 : 16,
              isMobile ? 10 : 12,
            ),
            child: Row(
              children: [
                _SecurityBadge(colorScheme: colorScheme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Browser Verification',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      _HostPill(host: host, colorScheme: colorScheme),
                    ],
                  ),
                ),
                _HeaderActionButtons(
                  onReload: onReload,
                  onCancel: onCancel,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
          _VerificationNoticeBanner(colorScheme: colorScheme, isMobile: isMobile),
        ],
      ),
    );
  }
}

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: colorScheme.onSurface.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SecurityBadge extends StatelessWidget {
  final ColorScheme colorScheme;

  const _SecurityBadge({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Icon(
        Icons.verified_user_rounded,
        size: 20,
        color: colorScheme.primary,
      ),
    );
  }
}

class _HostPill extends StatelessWidget {
  final String host;
  final ColorScheme colorScheme;

  const _HostPill({required this.host, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 12,
          color: colorScheme.primary.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            host,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _HeaderActionButtons extends StatelessWidget {
  final VoidCallback onReload;
  final VoidCallback onCancel;
  final ColorScheme colorScheme;

  const _HeaderActionButtons({
    required this.onReload,
    required this.onCancel,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Reload challenge',
          iconSize: 20,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            foregroundColor: colorScheme.onSurface.withValues(alpha: 0.75),
          ).copyWith(
            mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
          ),
          onPressed: onReload,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Cancel verification',
          iconSize: 20,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            backgroundColor: colorScheme.error.withValues(alpha: 0.1),
            foregroundColor: colorScheme.error,
          ).copyWith(
            mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
          ),
          onPressed: onCancel,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _VerificationNoticeBanner extends StatelessWidget {
  final ColorScheme colorScheme;
  final bool isMobile;

  const _VerificationNoticeBanner({
    required this.colorScheme,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 20,
        vertical: 6,
      ),
      color: colorScheme.primary.withValues(alpha: 0.05),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: colorScheme.primary.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Complete the challenge below. Closes automatically when verified.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11.5,
                color: colorScheme.onSurface.withValues(alpha: 0.75),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
