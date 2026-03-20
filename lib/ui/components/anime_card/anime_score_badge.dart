import 'package:flutter/material.dart';
import 'package:senpwai/ui/components/overlay_chip.dart';
import 'package:senpwai/ui/shared/responsive.dart';

class AnimeScoreBadge extends StatelessWidget {
  final double score;

  const AnimeScoreBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final desk = w >= Breakpoints.desktop;
    final iconSize = desk ? 14.0 : 12.0;
    final fontSize = desk ? 11.0 : 10.0;
    final padH = desk ? 7.0 : 6.0;
    final padV = desk ? 3.0 : 2.0;

    return OverlayChip(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: iconSize,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 2),
          Text(
            '${score.round()}',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
