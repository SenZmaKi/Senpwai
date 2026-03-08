import 'package:flutter/material.dart';
import 'package:senpwai/ui/shared/responsive.dart';

enum CardViewMode { poster, landscape, table }

class CardSwitcher extends StatelessWidget {
  final CardViewMode selected;
  final ValueChanged<CardViewMode> onSwitch;

  const CardSwitcher({
    super.key,
    required this.selected,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconSize = 18.0;
    final pillRadius = 10.0;
    final buttonSize = 34.0;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(pillRadius),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SwitcherItem(
            icon: Icons.grid_view,
            tooltip: 'Poster',
            selected: selected == CardViewMode.poster,
            size: buttonSize,
            iconSize: iconSize,
            radius: pillRadius - 1,
            onTap: () => onSwitch(CardViewMode.poster),
          ),
          _SwitcherItem(
            icon: Icons.art_track,
            tooltip: 'Landscape',
            selected: selected == CardViewMode.landscape,
            size: buttonSize,
            iconSize: iconSize,
            radius: pillRadius - 1,
            onTap: () => onSwitch(CardViewMode.landscape),
          ),
          _SwitcherItem(
            icon: Icons.view_list,
            tooltip: 'Table',
            selected: selected == CardViewMode.table,
            size: buttonSize,
            iconSize: iconSize,
            radius: pillRadius - 1,
            onTap: () => onSwitch(CardViewMode.table),
          ),
        ],
      ),
    );
  }
}

class _SwitcherItem extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final double size;
  final double iconSize;
  final double radius;
  final VoidCallback onTap;

  const _SwitcherItem({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.size,
    required this.iconSize,
    required this.radius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: selected
                    ? colorScheme.primary.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
