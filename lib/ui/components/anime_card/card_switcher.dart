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
    final mob = isMobile(context);
    final iconSize = mob ? 16.0 : 18.0;
    final padH = mob ? 6.0 : 8.0;
    final padV = mob ? 3.0 : 4.0;

    return SegmentedButton<CardViewMode>(
      segments: [
        ButtonSegment(
          value: CardViewMode.poster,
          icon: Icon(Icons.grid_view, size: iconSize),
          tooltip: 'Poster',
        ),
        ButtonSegment(
          value: CardViewMode.landscape,
          icon: Icon(Icons.art_track, size: iconSize),
          tooltip: 'Landscape',
        ),
        ButtonSegment(
          value: CardViewMode.table,
          icon: Icon(Icons.view_list, size: iconSize),
          tooltip: 'Table',
        ),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onSwitch(s.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        ),
      ),
    );
  }
}
