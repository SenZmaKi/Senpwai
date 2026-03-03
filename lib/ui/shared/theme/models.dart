import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum BrightnessMode {
  light,
  dark,
  system;

  String get label => switch (this) {
    BrightnessMode.light => 'Light',
    BrightnessMode.dark => 'Dark',
    BrightnessMode.system => 'System',
  };

  IconData get icon => switch (this) {
    BrightnessMode.light => Icons.light_mode,
    BrightnessMode.dark => Icons.dark_mode,
    BrightnessMode.system => Icons.brightness_auto,
  };
}

@immutable
class SenpwaiColorSet {
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color onSurface;
  final Color onPrimary;
  final Color error;
  final List<Color> genreColors;

  const SenpwaiColorSet({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.onSurface,
    required this.onPrimary,
    required this.error,
    required this.genreColors,
  });

  SenpwaiColorSet copyWith({
    Color? primary,
    Color? secondary,
    Color? tertiary,
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? onSurface,
    Color? onPrimary,
    Color? error,
    List<Color>? genreColors,
  }) {
    return SenpwaiColorSet(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      tertiary: tertiary ?? this.tertiary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      onSurface: onSurface ?? this.onSurface,
      onPrimary: onPrimary ?? this.onPrimary,
      error: error ?? this.error,
      genreColors: genreColors ?? this.genreColors,
    );
  }
}

@immutable
class SenpwaiColors {
  final SenpwaiColorSet dark;
  final SenpwaiColorSet light;

  const SenpwaiColors({required this.dark, required this.light});

  SenpwaiColors copyWith({SenpwaiColorSet? dark, SenpwaiColorSet? light}) {
    return SenpwaiColors(dark: dark ?? this.dark, light: light ?? this.light);
  }
}

@immutable
class SenpwaiTypography {
  final String displayFamily;
  final String bodyFamily;
  final double displayLargeSize;
  final double displayMediumSize;
  final double displaySmallSize;
  final double headlineLargeSize;
  final double headlineMediumSize;
  final double headlineSmallSize;
  final double bodyLargeSize;
  final double bodyMediumSize;
  final double bodySmallSize;
  final FontWeight displayWeight;
  final FontWeight headlineWeight;

  const SenpwaiTypography({
    required this.displayFamily,
    required this.bodyFamily,
    this.displayLargeSize = 32,
    this.displayMediumSize = 28,
    this.displaySmallSize = 24,
    this.headlineLargeSize = 22,
    this.headlineMediumSize = 20,
    this.headlineSmallSize = 18,
    this.bodyLargeSize = 16,
    this.bodyMediumSize = 14,
    this.bodySmallSize = 12,
    this.displayWeight = FontWeight.w700,
    this.headlineWeight = FontWeight.w600,
  });

  SenpwaiTypography copyWith({
    String? displayFamily,
    String? bodyFamily,
    double? displayLargeSize,
    double? displayMediumSize,
    double? displaySmallSize,
    double? headlineLargeSize,
    double? headlineMediumSize,
    double? headlineSmallSize,
    double? bodyLargeSize,
    double? bodyMediumSize,
    double? bodySmallSize,
    FontWeight? displayWeight,
    FontWeight? headlineWeight,
  }) {
    return SenpwaiTypography(
      displayFamily: displayFamily ?? this.displayFamily,
      bodyFamily: bodyFamily ?? this.bodyFamily,
      displayLargeSize: displayLargeSize ?? this.displayLargeSize,
      displayMediumSize: displayMediumSize ?? this.displayMediumSize,
      displaySmallSize: displaySmallSize ?? this.displaySmallSize,
      headlineLargeSize: headlineLargeSize ?? this.headlineLargeSize,
      headlineMediumSize: headlineMediumSize ?? this.headlineMediumSize,
      headlineSmallSize: headlineSmallSize ?? this.headlineSmallSize,
      bodyLargeSize: bodyLargeSize ?? this.bodyLargeSize,
      bodyMediumSize: bodyMediumSize ?? this.bodyMediumSize,
      bodySmallSize: bodySmallSize ?? this.bodySmallSize,
      displayWeight: displayWeight ?? this.displayWeight,
      headlineWeight: headlineWeight ?? this.headlineWeight,
    );
  }
}

List<String> availableGoogleFonts() => GoogleFonts.asMap().keys.toList();

@immutable
class SenpwaiShapeStyle {
  final double cardRadius;
  final double cardBorderWidth;
  final double inputRadius;
  final double buttonRadius;

  const SenpwaiShapeStyle({
    this.cardRadius = 4,
    this.cardBorderWidth = 1,
    this.inputRadius = 4,
    this.buttonRadius = 4,
  });

  SenpwaiShapeStyle copyWith({
    double? cardRadius,
    double? cardBorderWidth,
    double? inputRadius,
    double? buttonRadius,
  }) {
    return SenpwaiShapeStyle(
      cardRadius: cardRadius ?? this.cardRadius,
      cardBorderWidth: cardBorderWidth ?? this.cardBorderWidth,
      inputRadius: inputRadius ?? this.inputRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
    );
  }
}

enum RandomColourPalettePreset {
  vivid,
  pastel,
  muted,
  neon;

  String get label => switch (this) {
    RandomColourPalettePreset.vivid => 'Vivid',
    RandomColourPalettePreset.pastel => 'Pastel',
    RandomColourPalettePreset.muted => 'Muted',
    RandomColourPalettePreset.neon => 'Neon',
  };

  List<Color> get colors => switch (this) {
    RandomColourPalettePreset.vivid => const [
      Color(0xFFEF5350),
      Color(0xFFEC407A),
      Color(0xFFAB47BC),
      Color(0xFF7E57C2),
      Color(0xFF42A5F5),
      Color(0xFF26C6DA),
      Color(0xFF26A69A),
      Color(0xFF66BB6A),
      Color(0xFFD4E157),
      Color(0xFFFFCA28),
      Color(0xFFFFA726),
      Color(0xFF8D6E63),
    ],
    RandomColourPalettePreset.pastel => const [
      Color(0xFFEF9A9A),
      Color(0xFFF48FB1),
      Color(0xFFCE93D8),
      Color(0xFF90CAF9),
      Color(0xFF80DEEA),
      Color(0xFFA5D6A7),
      Color(0xFFFFE082),
      Color(0xFFFFCC80),
      Color(0xFF80CBC4),
      Color(0xFF9FA8DA),
      Color(0xFFC5E1A5),
      Color(0xFFBCAAA4),
    ],
    RandomColourPalettePreset.muted => const [
      Color(0xFF795548),
      Color(0xFF546E7A),
      Color(0xFF78909C),
      Color(0xFF558B2F),
      Color(0xFF37474F),
      Color(0xFF4527A0),
      Color(0xFF1565C0),
      Color(0xFF0277BD),
      Color(0xFF00695C),
      Color(0xFF827717),
      Color(0xFFC62828),
      Color(0xFF6D4C41),
    ],
    RandomColourPalettePreset.neon => const [
      Color(0xFFFF1744),
      Color(0xFFD500F9),
      Color(0xFF2979FF),
      Color(0xFF00E5FF),
      Color(0xFF00E676),
      Color(0xFFFFD600),
      Color(0xFFFF6D00),
      Color(0xFF1DE9B6),
      Color(0xFF3D5AFE),
      Color(0xFFF50057),
      Color(0xFF76FF03),
      Color(0xFFFFAB40),
    ],
  };
}
