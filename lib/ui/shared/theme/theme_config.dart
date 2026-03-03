import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'senpwai_theme.dart';
import 'theme_preset.dart';

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
