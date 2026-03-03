import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Brightness Mode ────────────────────────────────────────────────

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

// ── Color Set ──────────────────────────────────────────────────────

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

  /// Genre tag color palette for this color set.
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

// ── Colors (dark + light) ──────────────────────────────────────────

@immutable
class SenpwaiColors {
  final SenpwaiColorSet dark;
  final SenpwaiColorSet light;

  const SenpwaiColors({required this.dark, required this.light});

  SenpwaiColors copyWith({SenpwaiColorSet? dark, SenpwaiColorSet? light}) {
    return SenpwaiColors(dark: dark ?? this.dark, light: light ?? this.light);
  }
}

// ── Typography ─────────────────────────────────────────────────────

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

// ── Font helpers ───────────────────────────────────────────────────

List<String> availableGoogleFonts() => GoogleFonts.asMap().keys.toList();

// ── Shape ──────────────────────────────────────────────────────────

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

// ── Genre Palette Preset ──────────────────────────────────────────

enum GenrePalettePreset {
  vivid,
  pastel,
  muted,
  neon;

  String get label => switch (this) {
    GenrePalettePreset.vivid => 'Vivid',
    GenrePalettePreset.pastel => 'Pastel',
    GenrePalettePreset.muted => 'Muted',
    GenrePalettePreset.neon => 'Neon',
  };

  List<Color> get colors => switch (this) {
    GenrePalettePreset.vivid => const [
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
    GenrePalettePreset.pastel => const [
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
    GenrePalettePreset.muted => const [
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
    GenrePalettePreset.neon => const [
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

// ── Composed Theme ─────────────────────────────────────────────────

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
          genrePalette: c.genreColors,
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

// ── Theme Presets ──────────────────────────────────────────────────

enum SenpwaiThemePreset {
  defaultTheme,
  gruvbox,
  catppuccin,
  monokai;

  String get label => switch (this) {
    SenpwaiThemePreset.defaultTheme => 'Default',
    SenpwaiThemePreset.gruvbox => 'Gruvbox',
    SenpwaiThemePreset.catppuccin => 'Catppuccin',
    SenpwaiThemePreset.monokai => 'Monokai',
  };

  Color get swatch => toTheme().colors.dark.primary;

  SenpwaiTheme toTheme() => switch (this) {
    SenpwaiThemePreset.defaultTheme => const SenpwaiTheme(
      colors: SenpwaiColors(
        dark: SenpwaiColorSet(
          primary: Color(0xFFC4384E),
          secondary: Color(0xFFFF6B8A),
          tertiary: Color(0xFF4DD4E6),
          background: Color(0xFF080A0F),
          surface: Color(0xFF11141C),
          surfaceVariant: Color(0xFF1C1F2A),
          onSurface: Color(0xFFE2E8F0),
          onPrimary: Color(0xFFFFFFFF),
          error: Color(0xFFFF3333),
          genreColors: [
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
        ),
        light: SenpwaiColorSet(
          primary: Color(0xFF9B2C3E),
          secondary: Color(0xFFD14D6A),
          tertiary: Color(0xFF1A8FA0),
          background: Color(0xFFF5F0F1),
          surface: Color(0xFFFFFFFF),
          surfaceVariant: Color(0xFFF0E6E8),
          onSurface: Color(0xFF1A1A2E),
          onPrimary: Color(0xFFFFFFFF),
          error: Color(0xFFCC2222),
          genreColors: [
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
        ),
      ),
      typography: SenpwaiTypography(
        displayFamily: 'Orbitron',
        bodyFamily: 'Exo 2',
      ),
      shape: SenpwaiShapeStyle(
        cardRadius: 4,
        cardBorderWidth: 1,
        inputRadius: 4,
        buttonRadius: 4,
      ),
    ),
    SenpwaiThemePreset.gruvbox => const SenpwaiTheme(
      colors: SenpwaiColors(
        dark: SenpwaiColorSet(
          primary: Color(0xFFD79921),
          secondary: Color(0xFFB8BB26),
          tertiary: Color(0xFF83A598),
          background: Color(0xFF1D2021),
          surface: Color(0xFF282828),
          surfaceVariant: Color(0xFF3C3836),
          onSurface: Color(0xFFEBDBB2),
          onPrimary: Color(0xFF1D2021),
          error: Color(0xFFCC241D),
          genreColors: [
            Color(0xFFFF6D00),
            Color(0xFFD79921),
            Color(0xFF8EC07C),
            Color(0xFF83A598),
            Color(0xFFB57614),
            Color(0xFFCC241D),
            Color(0xFFD65D0E),
            Color(0xFF458588),
            Color(0xFF689D6A),
            Color(0xFFB8BB26),
            Color(0xFFD3869B),
            Color(0xFF98971A),
          ],
        ),
        light: SenpwaiColorSet(
          primary: Color(0xFFB57614),
          secondary: Color(0xFF79740E),
          tertiary: Color(0xFF427B58),
          background: Color(0xFFFBF1C7),
          surface: Color(0xFFF2E5BC),
          surfaceVariant: Color(0xFFEBDBB2),
          onSurface: Color(0xFF3C3836),
          onPrimary: Color(0xFFFBF1C7),
          error: Color(0xFF9D0006),
          genreColors: [
            Color(0xFFFF6D00),
            Color(0xFFD79921),
            Color(0xFF8EC07C),
            Color(0xFF83A598),
            Color(0xFFB57614),
            Color(0xFFCC241D),
            Color(0xFFD65D0E),
            Color(0xFF458588),
            Color(0xFF689D6A),
            Color(0xFFB8BB26),
            Color(0xFFD3869B),
            Color(0xFF98971A),
          ],
        ),
      ),
      typography: SenpwaiTypography(
        displayFamily: 'Bitter',
        bodyFamily: 'Source Sans 3',
      ),
      shape: SenpwaiShapeStyle(
        cardRadius: 6,
        cardBorderWidth: 1.5,
        inputRadius: 6,
        buttonRadius: 6,
      ),
    ),
    SenpwaiThemePreset.catppuccin => const SenpwaiTheme(
      colors: SenpwaiColors(
        dark: SenpwaiColorSet(
          primary: Color(0xFFCBA6F7),
          secondary: Color(0xFFF5C2E7),
          tertiary: Color(0xFF94E2D5),
          background: Color(0xFF1E1E2E),
          surface: Color(0xFF181825),
          surfaceVariant: Color(0xFF313244),
          onSurface: Color(0xFFCDD6F4),
          onPrimary: Color(0xFF1E1E2E),
          error: Color(0xFFF38BA8),
          genreColors: [
            Color(0xFFEBA0AC),
            Color(0xFFF5C2E7),
            Color(0xFFCBA6F7),
            Color(0xFF89B4FA),
            Color(0xFF74C7EC),
            Color(0xFF89DCEB),
            Color(0xFF94E2D5),
            Color(0xFFA6E3A1),
            Color(0xFFB5E8B0),
            Color(0xFFFFD080),
            Color(0xFFFAB387),
            Color(0xFFF38BA8),
          ],
        ),
        light: SenpwaiColorSet(
          primary: Color(0xFF8839EF),
          secondary: Color(0xFFEA76CB),
          tertiary: Color(0xFF179299),
          background: Color(0xFFEFF1F5),
          surface: Color(0xFFFFFFFF),
          surfaceVariant: Color(0xFFE6E9EF),
          onSurface: Color(0xFF4C4F69),
          onPrimary: Color(0xFFEFF1F5),
          error: Color(0xFFD20F39),
          genreColors: [
            Color(0xFFEBA0AC),
            Color(0xFFF5C2E7),
            Color(0xFFCBA6F7),
            Color(0xFF89B4FA),
            Color(0xFF74C7EC),
            Color(0xFF89DCEB),
            Color(0xFF94E2D5),
            Color(0xFFA6E3A1),
            Color(0xFFB5E8B0),
            Color(0xFFFFD080),
            Color(0xFFFAB387),
            Color(0xFFF38BA8),
          ],
        ),
      ),
      typography: SenpwaiTypography(
        displayFamily: 'Comfortaa',
        bodyFamily: 'Nunito Sans',
        displayWeight: FontWeight.w600,
        headlineWeight: FontWeight.w500,
      ),
      shape: SenpwaiShapeStyle(
        cardRadius: 10,
        cardBorderWidth: 0,
        inputRadius: 10,
        buttonRadius: 10,
      ),
    ),
    SenpwaiThemePreset.monokai => const SenpwaiTheme(
      colors: SenpwaiColors(
        dark: SenpwaiColorSet(
          primary: Color(0xFFA6E22E),
          secondary: Color(0xFFF92672),
          tertiary: Color(0xFF66D9EF),
          background: Color(0xFF1E1F1C),
          surface: Color(0xFF272822),
          surfaceVariant: Color(0xFF3E3D32),
          onSurface: Color(0xFFF8F8F2),
          onPrimary: Color(0xFF272822),
          error: Color(0xFFF92672),
          genreColors: [
            Color(0xFFA6E22E),
            Color(0xFFF92672),
            Color(0xFF66D9EF),
            Color(0xFFE6DB74),
            Color(0xFFFD971F),
            Color(0xFF819AFF),
            Color(0xFFCC66FF),
            Color(0xFF4DD4E6),
            Color(0xFFFF7043),
            Color(0xFF80CBC4),
            Color(0xFFFF80AB),
            Color(0xFFB9EE6A),
          ],
        ),
        light: SenpwaiColorSet(
          primary: Color(0xFF4D7A0F),
          secondary: Color(0xFFC2185B),
          tertiary: Color(0xFF0277BD),
          background: Color(0xFFF8F8F2),
          surface: Color(0xFFFFFFFF),
          surfaceVariant: Color(0xFFEEEDE5),
          onSurface: Color(0xFF272822),
          onPrimary: Color(0xFFF8F8F2),
          error: Color(0xFFC2185B),
          genreColors: [
            Color(0xFFA6E22E),
            Color(0xFFF92672),
            Color(0xFF66D9EF),
            Color(0xFFE6DB74),
            Color(0xFFFD971F),
            Color(0xFF819AFF),
            Color(0xFFCC66FF),
            Color(0xFF4DD4E6),
            Color(0xFFFF7043),
            Color(0xFF80CBC4),
            Color(0xFFFF80AB),
            Color(0xFFB9EE6A),
          ],
        ),
      ),
      typography: SenpwaiTypography(
        displayFamily: 'JetBrains Mono',
        bodyFamily: 'Barlow',
      ),
      shape: SenpwaiShapeStyle(
        cardRadius: 2,
        cardBorderWidth: 1,
        inputRadius: 2,
        buttonRadius: 2,
      ),
    ),
  };
}

// ── Theme Config ───────────────────────────────────────────────────

@immutable
class ThemeConfig {
  final BrightnessMode brightnessMode;
  final SenpwaiTheme theme;
  final SenpwaiThemePreset? activePreset;

  ThemeConfig({
    this.brightnessMode = BrightnessMode.dark,
    SenpwaiThemePreset preset = SenpwaiThemePreset.defaultTheme,
    SenpwaiTheme? theme,
    this.activePreset,
  }) : theme = theme ?? preset.toTheme();

  SenpwaiColors get colors => theme.colors;
  SenpwaiTypography get typography => theme.typography;
  SenpwaiShapeStyle get shape => theme.shape;

  ThemeMode get themeMode => switch (brightnessMode) {
    BrightnessMode.light => ThemeMode.light,
    BrightnessMode.dark => ThemeMode.dark,
    BrightnessMode.system => ThemeMode.system,
  };

  ThemeData buildLightTheme() => theme.toThemeData(Brightness.light);
  ThemeData buildDarkTheme() => theme.toThemeData(Brightness.dark);

  ThemeConfig copyWith({
    BrightnessMode? brightnessMode,
    SenpwaiTheme? theme,
    SenpwaiThemePreset? activePreset,
  }) {
    return ThemeConfig(
      brightnessMode: brightnessMode ?? this.brightnessMode,
      theme: theme ?? this.theme,
      activePreset: activePreset,
    );
  }
}

class ThemeConfigNotifier extends Notifier<ThemeConfig> {
  static final provider = NotifierProvider<ThemeConfigNotifier, ThemeConfig>(
    ThemeConfigNotifier.new,
  );

  @override
  ThemeConfig build() => ThemeConfig();

  void setBrightnessMode(BrightnessMode mode) {
    if (state.brightnessMode == mode) return;
    state = state.copyWith(
      brightnessMode: mode,
      activePreset: state.activePreset,
    );
  }

  void setTheme(SenpwaiTheme theme) {
    state = state.copyWith(theme: theme, activePreset: null);
  }

  void setColors(SenpwaiColors colors) {
    state = state.copyWith(
      theme: state.theme.copyWith(colors: colors),
      activePreset: null,
    );
  }

  void setTypography(SenpwaiTypography typography) {
    state = state.copyWith(theme: state.theme.copyWith(typography: typography));
  }

  void setShape(SenpwaiShapeStyle shape) {
    state = state.copyWith(theme: state.theme.copyWith(shape: shape));
  }

  void applyPreset(SenpwaiThemePreset preset) {
    state = ThemeConfig(
      brightnessMode: state.brightnessMode,
      theme: preset.toTheme(),
      activePreset: preset,
    );
  }
}

// ── Theme Extension ────────────────────────────────────────────────

@immutable
class SenpwaiThemeExtension extends ThemeExtension<SenpwaiThemeExtension> {
  final double cardRadius;
  final Color cardBorderColor;
  final double cardBorderWidth;
  final List<BoxShadow> cardShadows;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final List<Color> genrePalette;

  const SenpwaiThemeExtension({
    required this.cardRadius,
    required this.cardBorderColor,
    required this.cardBorderWidth,
    required this.cardShadows,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.genrePalette,
  });

  @override
  SenpwaiThemeExtension copyWith({
    double? cardRadius,
    Color? cardBorderColor,
    double? cardBorderWidth,
    List<BoxShadow>? cardShadows,
    Color? shimmerBase,
    Color? shimmerHighlight,
    List<Color>? genrePalette,
  }) {
    return SenpwaiThemeExtension(
      cardRadius: cardRadius ?? this.cardRadius,
      cardBorderColor: cardBorderColor ?? this.cardBorderColor,
      cardBorderWidth: cardBorderWidth ?? this.cardBorderWidth,
      cardShadows: cardShadows ?? this.cardShadows,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      genrePalette: genrePalette ?? this.genrePalette,
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
      genrePalette: t < 0.5 ? genrePalette : other.genrePalette,
    );
  }
}

// ── Private helpers ────────────────────────────────────────────────

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
