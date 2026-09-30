import 'package:flutter/material.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

class OverlayChip extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const OverlayChip({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(ext.cardRadius.clamp(0, 8)),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}
