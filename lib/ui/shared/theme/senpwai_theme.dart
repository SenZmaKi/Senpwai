import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models.dart';
import 'theme_extension.dart';

@immutable
class SenpwaiTheme {
  final SenpwaiColors colors;
  final SenpwaiTypography typography;
  final SenpwaiShapeStyle shape;

  const SenpwaiTheme({
    required this.colors,
    required this.typography,
    required this.shape,
  });

  SenpwaiTheme copyWith({
    SenpwaiColors? colors,
    SenpwaiTypography? typography,
    SenpwaiShapeStyle? shape,
  }) {
    return SenpwaiTheme(
      colors: colors ?? this.colors,
      typography: typography ?? this.typography,
      shape: shape ?? this.shape,
    );
  }

  ThemeData toThemeData(Brightness brightness) {
    final c = brightness == Brightness.dark ? colors.dark : colors.light;
    final t = typography;
    final s = shape;
    final isDark = brightness == Brightness.dark;

    final colorScheme =
        (isDark ? const ColorScheme.dark() : const ColorScheme.light())
            .copyWith(
              primary: c.primary,
              onPrimary: c.onPrimary,
              secondary: c.secondary,
              onSecondary: isDark ? Colors.black : Colors.white,
              tertiary: c.tertiary,
              surface: c.surface,
              surfaceContainerHighest: c.surfaceVariant,
              onSurface: c.onSurface,
              error: c.error,
            );

    final displayFont = _googleFont(t.displayFamily);
    final bodyFont = _googleFont(t.bodyFamily);

    final textTheme = _buildTextTheme(c.onSurface, brightness, t);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: displayFont(
          fontSize: t.headlineSmallSize,
          fontWeight: t.headlineWeight,
          color: c.primary,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(s.cardRadius),
          side: BorderSide(color: c.primary.withValues(alpha: 0.3)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(s.inputRadius),
          borderSide: BorderSide(color: c.primary.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(s.inputRadius),
          borderSide: BorderSide(color: c.primary.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(s.inputRadius),
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
        hintStyle: bodyFont(color: c.onSurface.withValues(alpha: 0.4)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(s.buttonRadius),
          ),
          textStyle: bodyFont(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          side: BorderSide(color: c.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(s.buttonRadius),
          ),
          textStyle: bodyFont(fontWeight: FontWeight.w600),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return c.primary.withValues(alpha: 0.2);
            }
            return c.surfaceVariant;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return c.primary;
            return c.onSurface.withValues(alpha: 0.6);
          }),
          side: WidgetStateProperty.all(
            BorderSide(color: c.primary.withValues(alpha: 0.3)),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(s.buttonRadius),
            ),
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.background,
        selectedIconTheme: IconThemeData(color: c.primary),
        unselectedIconTheme: IconThemeData(
          color: c.onSurface.withValues(alpha: 0.4),
        ),
        indicatorColor: c.primary.withValues(alpha: 0.15),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.background,
        indicatorColor: c.primary.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: c.primary);
          }
          return IconThemeData(color: c.onSurface.withValues(alpha: 0.4));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return bodyFont(
              color: c.primary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            );
          }
          return bodyFont(
            color: c.onSurface.withValues(alpha: 0.4),
            fontSize: 11,
          );
        }),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: c.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(s.inputRadius),
            borderSide: BorderSide(color: c.primary.withValues(alpha: 0.3)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceVariant,
        selectedColor: c.primary.withValues(alpha: 0.2),
        labelStyle: bodyFont(fontSize: t.bodySmallSize),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(s.cardRadius),
          side: BorderSide(color: c.primary.withValues(alpha: 0.3)),
        ),
        side: BorderSide(color: c.primary.withValues(alpha: 0.3)),
      ),
      dividerTheme: DividerThemeData(color: c.primary.withValues(alpha: 0.15)),
      iconTheme: IconThemeData(color: c.onSurface),
      extensions: [
        SenpwaiThemeExtension(
          cardRadius: s.cardRadius,
          cardBorderColor: c.primary.withValues(alpha: 0.3),
          cardBorderWidth: s.cardBorderWidth,
          randomColourPalette: c.genreColors,
          cardShadows: isDark
              ? [
                  BoxShadow(
                    color: c.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                  ),
                ]
              : [
                  BoxShadow(
                    color: c.onSurface.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
          shimmerBase: c.surface,
          shimmerHighlight: c.surfaceVariant,
        ),
      ],
    );
  }
}

TextStyle Function({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  double? letterSpacing,
})
_googleFont(String family) {
  return ({color, fontSize, fontWeight, letterSpacing}) => GoogleFonts.getFont(
    family,
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
  );
}

TextTheme _buildTextTheme(
  Color color,
  Brightness brightness,
  SenpwaiTypography t,
) {
  final base = brightness == Brightness.dark
      ? ThemeData.dark().textTheme
      : ThemeData.light().textTheme;

  final displayFont = _googleFont(t.displayFamily);
  final bodyFont = _googleFont(t.bodyFamily);

  return GoogleFonts.getTextTheme(t.bodyFamily, base)
      .copyWith(
        displayLarge: displayFont(
          fontSize: t.displayLargeSize,
          fontWeight: t.displayWeight,
          color: color,
        ),
        displayMedium: displayFont(
          fontSize: t.displayMediumSize,
          fontWeight: t.displayWeight,
          color: color,
        ),
        displaySmall: displayFont(
          fontSize: t.displaySmallSize,
          fontWeight: t.headlineWeight,
          color: color,
        ),
        headlineLarge: displayFont(
          fontSize: t.headlineLargeSize,
          fontWeight: t.headlineWeight,
          color: color,
        ),
        headlineMedium: displayFont(
          fontSize: t.headlineMediumSize,
          fontWeight: t.headlineWeight,
          color: color,
        ),
        headlineSmall: displayFont(
          fontSize: t.headlineSmallSize,
          fontWeight: FontWeight.w500,
          color: color,
        ),
        bodyLarge: bodyFont(fontSize: t.bodyLargeSize, color: color),
        bodyMedium: bodyFont(fontSize: t.bodyMediumSize, color: color),
        bodySmall: bodyFont(fontSize: t.bodySmallSize, color: color),
      )
      .apply(bodyColor: color, displayColor: color);
}
