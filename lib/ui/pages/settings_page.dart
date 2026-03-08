import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';
import 'package:senpwai/ui/shared/responsive.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _autoUpdate = false;
  bool _nsfwFilter = true;
  double _downloadQuality = 1;
  String _preferredTitleLanguage = 'romaji';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(ThemeConfigNotifier.provider);
    final notifier = ref.read(ThemeConfigNotifier.provider.notifier);
    final pad = horizontalPadding(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 24, pad, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(title: 'Appearance', icon: Icons.palette),
                  const SizedBox(height: 12),
                  _buildBrightnessSelector(context, config, notifier),
                  const SizedBox(height: 16),
                  _buildPaletteSelector(context, config, notifier),
                  const SizedBox(height: 16),
                  _buildFontPicker(context, config, notifier),
                  const SizedBox(height: 24),

                  _SectionTitle(title: 'General', icon: Icons.tune),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.language,
                    title: 'Preferred Title Language',
                    subtitle: 'Choose which title format to display',
                    trailing: DropdownButton<String>(
                      value: _preferredTitleLanguage,
                      underline: const SizedBox.shrink(),
                      style: theme.textTheme.bodySmall,
                      dropdownColor: theme.colorScheme.surfaceContainerHighest,
                      items: const [
                        DropdownMenuItem(
                          value: 'romaji',
                          child: Text('Romaji'),
                        ),
                        DropdownMenuItem(
                          value: 'english',
                          child: Text('English'),
                        ),
                        DropdownMenuItem(
                          value: 'native',
                          child: Text('Native'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _preferredTitleLanguage = v);
                        }
                      },
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.filter_alt_outlined,
                    title: 'NSFW Filter',
                    subtitle: 'Hide adult content from results',
                    trailing: Switch.adaptive(
                      value: _nsfwFilter,
                      onChanged: (v) => setState(() => _nsfwFilter = v),
                      activeColor: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _SectionTitle(title: 'Downloads', icon: Icons.download),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.high_quality,
                    title: 'Download Quality',
                    subtitle: _qualityLabel,
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: _downloadQuality,
                        min: 0,
                        max: 2,
                        divisions: 2,
                        label: _qualityLabel,
                        activeColor: theme.colorScheme.primary,
                        onChanged: (v) => setState(() => _downloadQuality = v),
                      ),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.update,
                    title: 'Auto-Update Downloads',
                    subtitle: 'Automatically fetch new episodes',
                    trailing: Switch.adaptive(
                      value: _autoUpdate,
                      onChanged: (v) => setState(() => _autoUpdate = v),
                      activeColor: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _SectionTitle(
                    title: 'Notifications',
                    icon: Icons.notifications_none,
                  ),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Push Notifications',
                    subtitle: 'Get notified for new episodes',
                    trailing: Switch.adaptive(
                      value: _notificationsEnabled,
                      onChanged: (v) =>
                          setState(() => _notificationsEnabled = v),
                      activeColor: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _SectionTitle(title: 'About', icon: Icons.info_outline),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.code,
                    title: 'Version',
                    subtitle: '1.0.0',
                  ),
                  _SettingsTile(
                    icon: Icons.description_outlined,
                    title: 'Licenses',
                    subtitle: 'View open source licenses',
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'Senpwai',
                        applicationVersion: '1.0.0',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String get _qualityLabel {
    if (_downloadQuality <= 0) return 'Low (480p)';
    if (_downloadQuality <= 1) return 'Medium (720p)';
    return 'High (1080p)';
  }

  Widget _buildBrightnessSelector(
    BuildContext context,
    ThemeConfig config,
    ThemeConfigNotifier notifier,
  ) {
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

  Widget _buildPaletteSelector(
    BuildContext context,
    ThemeConfig config,
    ThemeConfigNotifier notifier,
  ) {
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

  Widget _buildFontPicker(
    BuildContext context,
    ThemeConfig config,
    ThemeConfigNotifier notifier,
  ) {
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
              child: _FontAutocomplete(
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
              child: _FontAutocomplete(
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _FontAutocomplete extends StatelessWidget {
  final String label;
  final String currentValue;
  final List<String> allFonts;
  final ValueChanged<String> onSelected;

  const _FontAutocomplete({
    super.key,
    required this.label,
    required this.currentValue,
    required this.allFonts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: currentValue),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return allFonts;
        return allFonts.where((f) => f.toLowerCase().contains(query)).toList();
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: label, isDense: true),
          onSubmitted: (_) => onSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final theme = Theme.of(context);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option, style: theme.textTheme.bodyMedium),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
