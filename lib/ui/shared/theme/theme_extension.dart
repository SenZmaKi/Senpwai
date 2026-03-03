import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class SenpwaiThemeExtension extends ThemeExtension<SenpwaiThemeExtension> {
  final double cardRadius;
  final Color cardBorderColor;
  final double cardBorderWidth;
  final List<BoxShadow> cardShadows;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final List<Color> randomColourPalette;
  final Color imageOverlay;
  final Color onImageOverlay;
  final Color textShadow;

  Color randomColour(int seed) =>
      randomColourPalette[seed.abs() % randomColourPalette.length];

  const SenpwaiThemeExtension({
    required this.cardRadius,
    required this.cardBorderColor,
    required this.cardBorderWidth,
    required this.cardShadows,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.randomColourPalette,
    required this.imageOverlay,
    required this.onImageOverlay,
    required this.textShadow,
  });

  @override
  SenpwaiThemeExtension copyWith({
    double? cardRadius,
    Color? cardBorderColor,
    double? cardBorderWidth,
    List<BoxShadow>? cardShadows,
    Color? shimmerBase,
    Color? shimmerHighlight,
    List<Color>? randomColourPalette,
    Color? imageOverlay,
    Color? onImageOverlay,
    Color? textShadow,
  }) {
    return SenpwaiThemeExtension(
      cardRadius: cardRadius ?? this.cardRadius,
      cardBorderColor: cardBorderColor ?? this.cardBorderColor,
      cardBorderWidth: cardBorderWidth ?? this.cardBorderWidth,
      cardShadows: cardShadows ?? this.cardShadows,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      randomColourPalette: randomColourPalette ?? this.randomColourPalette,
      imageOverlay: imageOverlay ?? this.imageOverlay,
      onImageOverlay: onImageOverlay ?? this.onImageOverlay,
      textShadow: textShadow ?? this.textShadow,
    );
  }

  @override
  SenpwaiThemeExtension lerp(SenpwaiThemeExtension? other, double t) {
    if (other == null) return this;
    return SenpwaiThemeExtension(
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t) ?? cardRadius,
      cardBorderColor:
          Color.lerp(cardBorderColor, other.cardBorderColor, t) ??
          cardBorderColor,
      cardBorderWidth:
          lerpDouble(cardBorderWidth, other.cardBorderWidth, t) ??
          cardBorderWidth,
      cardShadows: t < 0.5 ? cardShadows : other.cardShadows,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t) ?? shimmerBase,
      shimmerHighlight:
          Color.lerp(shimmerHighlight, other.shimmerHighlight, t) ??
          shimmerHighlight,
      randomColourPalette: t < 0.5
          ? randomColourPalette
          : other.randomColourPalette,
      imageOverlay:
          Color.lerp(imageOverlay, other.imageOverlay, t) ?? imageOverlay,
      onImageOverlay:
          Color.lerp(onImageOverlay, other.onImageOverlay, t) ?? onImageOverlay,
      textShadow: Color.lerp(textShadow, other.textShadow, t) ?? textShadow,
    );
  }
}
