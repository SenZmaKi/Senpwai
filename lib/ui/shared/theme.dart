import 'package:flutter/material.dart';

enum ColorTheme {
  default_,
  crimson,
  emerald,
  sapphire,
  amethyst,
  ruby,
  topaz,
  autumn,
}

extension ColorThemeExtension on ColorTheme {
  MaterialColor get color => switch (this) {
    ColorTheme.default_ => Colors.amber,
    ColorTheme.crimson => Colors.red,
    ColorTheme.emerald => Colors.green,
    ColorTheme.sapphire => Colors.blue,
    ColorTheme.amethyst => Colors.purple,
    ColorTheme.ruby => Colors.pink,
    ColorTheme.topaz => Colors.yellow,
    ColorTheme.autumn => Colors.orange,
  };

  Color negativeColor() => switch (this) {
    ColorTheme.crimson => Colors.amber,
    _ => Colors.red,
  };

  String get displayName => switch (this) {
    ColorTheme.default_ => "Default",
    ColorTheme.crimson => "Crimson",
    ColorTheme.emerald => "Emerald",
    ColorTheme.sapphire => "Sapphire",
    ColorTheme.amethyst => "Amethyst",
    ColorTheme.ruby => "Ruby",
    ColorTheme.topaz => "Topaz",
    ColorTheme.autumn => "Autumn",
  };
}
