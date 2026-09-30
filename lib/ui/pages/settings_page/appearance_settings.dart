import 'dart:async';

import 'package:flutter/material.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/ui/components/anime_card/card_switcher.dart';
import 'package:senpwai/ui/pages/settings_page/font_autocomplete.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';
import 'package:senpwai/ui/pages/settings_page/window_settings.dart';
import 'package:senpwai/ui/shared/window_manager.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

class AppearanceSettings extends StatelessWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;
  final String? searchQuery;

  const AppearanceSettings({
    super.key,
    required this.settings,
    required this.notifier,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupCard(
          title: 'Theme & Style',
          icon: Icons.palette_outlined,
          description: 'Customize brightness mode and active color theme',
          searchQuery: searchQuery,
          searchTerms: [
            'Brightness light dark system',
            'Color palette',
            for (final preset in SenpwaiThemePreset.values) preset.label,
          ],
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BrightnessSelector(settings: settings, notifier: notifier),
                  const SizedBox(height: 20),
                  _PaletteSelector(settings: settings, notifier: notifier),
                ],
              ),
            ),
          ],
        ),
        SettingsGroupCard(
          title: 'Typography',
          icon: Icons.text_fields_rounded,
          description: 'Set custom Google Fonts for headers and body text',
          searchQuery: searchQuery,
          searchTerms: [
            'Display font',
            'Body font',
            settings.appearance.displayFontFamily,
            settings.appearance.bodyFontFamily,
          ],
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _FontPicker(settings: settings, notifier: notifier),
            ),
          ],
        ),
        SettingsGroupCard(
          title: 'Card Layout',
          icon: Icons.view_quilt_outlined,
          description: 'Choose how anime cards appear across the app',
          searchQuery: searchQuery,
          searchTerms: const [
            'Card view layout',
            'Poster grid',
            'Landscape',
            'Table list',
            'Home search results',
          ],
          children: [
            SettingsTile(
              icon: Icons.dashboard_customize_outlined,
              title: 'Anime card style',
              subtitle: 'Used on Home and Search',
              keywords: 'poster landscape table grid list',
              searchQuery: searchQuery,
              trailing: CardSwitcher(
                selected: settings.appearance.cardViewMode,
                onSwitch: (mode) => unawaited(notifier.setCardViewMode(mode)),
              ),
            ),
          ],
        ),
        if (supportsWindowCustomization)
          WindowSettings(
            settings: settings,
            notifier: notifier,
            searchQuery: searchQuery,
          ),
      ],
    );
  }
}

class _BrightnessSelector extends StatelessWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;

  const _BrightnessSelector({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Brightness',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<BrightnessMode>(
            segments: BrightnessMode.values
                .map(
                  (mode) => ButtonSegment(
                    value: mode,
                    label: Text(mode.label, softWrap: false),
                    icon: Icon(mode.icon),
                  ),
                )
                .toList(),
            selected: {settings.appearance.brightnessMode},
            onSelectionChanged: (selected) =>
                unawaited(notifier.setBrightnessMode(selected.first)),
            style: ButtonStyle(
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ext.cardRadius),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaletteSelector extends StatelessWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;

  const _PaletteSelector({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color Palette',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: SenpwaiThemePreset.values.map((preset) {
            final selected = preset == settings.appearance.themePreset;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => unawaited(notifier.setThemePreset(preset)),
                child: Tooltip(
                  message: preset.label,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: preset.swatch,
                      borderRadius: BorderRadius.circular(ext.cardRadius),
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.onSurface
                            : preset.swatch.withValues(alpha: 0.3),
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: selected
                        ? Icon(
                            Icons.check,
                            color: preset.swatch.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FontPicker extends StatelessWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;

  const _FontPicker({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final allFonts = availableGoogleFonts();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: FontAutocomplete(
            key: ValueKey('display_${settings.appearance.displayFontFamily}'),
            label: 'Display Font',
            currentValue: settings.appearance.displayFontFamily,
            allFonts: allFonts,
            onSelected: (value) =>
                unawaited(notifier.setDisplayFontFamily(value)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FontAutocomplete(
            key: ValueKey('body_${settings.appearance.bodyFontFamily}'),
            label: 'Body Font',
            currentValue: settings.appearance.bodyFontFamily,
            allFonts: allFonts,
            onSelected: (value) => unawaited(notifier.setBodyFontFamily(value)),
          ),
        ),
      ],
    );
  }
}
