import 'package:flutter/material.dart';
import 'package:senpwai/ui/pages/settings_page/font_autocomplete.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

class AppearanceSettings extends StatelessWidget {
  final ThemeConfig config;
  final ThemeConfigNotifier notifier;

  const AppearanceSettings({
    super.key,
    required this.config,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BrightnessSelector(config: config, notifier: notifier),
        const SizedBox(height: 16),
        _PaletteSelector(config: config, notifier: notifier),
        const SizedBox(height: 16),
        _FontPicker(config: config, notifier: notifier),
      ],
    );
  }
}

class _BrightnessSelector extends StatelessWidget {
  final ThemeConfig config;
  final ThemeConfigNotifier notifier;

  const _BrightnessSelector({required this.config, required this.notifier});

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
                  (m) => ButtonSegment(
                    value: m,
                    label: Text(m.label, softWrap: false),
                    icon: Icon(m.icon),
                  ),
                )
                .toList(),
            selected: {config.brightnessMode},
            onSelectionChanged: (s) => notifier.setBrightnessMode(s.first),
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
  final ThemeConfig config;
  final ThemeConfigNotifier notifier;

  const _PaletteSelector({required this.config, required this.notifier});

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
            final selected = preset == config.activePreset;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => notifier.applyPreset(preset),
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
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: preset.swatch.withValues(alpha: 0.4),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
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
  final ThemeConfig config;
  final ThemeConfigNotifier notifier;

  const _FontPicker({required this.config, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allFonts = availableGoogleFonts();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fonts',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FontAutocomplete(
                key: ValueKey('display_${config.typography.displayFamily}'),
                label: 'Display',
                currentValue: config.typography.displayFamily,
                allFonts: allFonts,
                onSelected: (v) {
                  notifier.setTypography(
                    config.typography.copyWith(displayFamily: v),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FontAutocomplete(
                key: ValueKey('body_${config.typography.bodyFamily}'),
                label: 'Body',
                currentValue: config.typography.bodyFamily,
                allFonts: allFonts,
                onSelected: (v) {
                  notifier.setTypography(
                    config.typography.copyWith(bodyFamily: v),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
