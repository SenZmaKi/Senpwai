import 'package:flutter/material.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

class DownloadsEmptyState extends StatelessWidget {
  const DownloadsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final senpwai = theme.extension<SenpwaiThemeExtension>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(senpwai?.cardRadius ?? 8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(
                  Icons.playlist_add_check_circle_outlined,
                  size: 42,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No Downloads Yet',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start downloads from an anime page and they will land here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
