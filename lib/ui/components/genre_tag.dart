import 'package:flutter/material.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

class GenreTag extends StatelessWidget {
  final String name;
  final double fontSize;

  const GenreTag({super.key, required this.name, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<SenpwaiThemeExtension>()!;
    final hash = name.codeUnits.fold(0, (int p, int c) => p * 31 + c);
    final color = ext.randomColour(hash);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
