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
  final List<Color> randomColors;
  final Color imageOverlay;
  final Color onImageOverlay;
  final Color textShadow;

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
    required this.randomColors,
    required this.imageOverlay,
    required this.onImageOverlay,
    required this.textShadow,
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
    List<Color>? randomColors,
    Color? imageOverlay,
    Color? onImageOverlay,
    Color? textShadow,
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
      randomColors: randomColors ?? this.randomColors,
      imageOverlay: imageOverlay ?? this.imageOverlay,
      onImageOverlay: onImageOverlay ?? this.onImageOverlay,
      textShadow: textShadow ?? this.textShadow,
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
