import 'package:flutter/material.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

mixin CardHoverMixin<T extends StatefulWidget> on State<T> {
  bool _hovered = false;

  Widget buildHoverableCard({
    required Widget child,
    required SenpwaiThemeExtension ext,
    required ThemeData theme,
    VoidCallback? onTap,
    double hoverScale = 1.03,
  }) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: AnimatedScale(
          scale: _hovered && !reduceMotion ? hoverScale : 1.0,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(ext.cardRadius),
              border: ext.cardBorderWidth > 0
                  ? Border.all(
                      color: ext.cardBorderColor,
                      width: ext.cardBorderWidth,
                    )
                  : null,
              boxShadow: _hovered
                  ? ext.cardShadows
                        .map(
                          (s) => BoxShadow(
                            color: s.color.withValues(alpha: s.color.a * 1.6),
                            blurRadius: s.blurRadius * 1.5,
                            offset: s.offset,
                          ),
                        )
                        .toList()
                  : ext.cardShadows,
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ),
    );
  }
}
