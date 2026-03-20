import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/ui/pages/settings_page/appearance_settings.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';
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
                  const SettingsSectionTitle(
                    title: 'Appearance',
                    icon: Icons.palette,
                  ),
                  const SizedBox(height: 12),
                  AppearanceSettings(config: config, notifier: notifier),
                  const SizedBox(height: 24),

                  const SettingsSectionTitle(
                    title: 'General',
                    icon: Icons.tune,
                  ),
                  const SizedBox(height: 8),
                  SettingsTile(
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
                  SettingsTile(
                    icon: Icons.filter_alt_outlined,
                    title: 'NSFW Filter',
                    subtitle: 'Hide adult content from results',
                    trailing: Switch.adaptive(
                      value: _nsfwFilter,
                      onChanged: (v) => setState(() => _nsfwFilter = v),
                      activeTrackColor: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  const SettingsSectionTitle(
                    title: 'Downloads',
                    icon: Icons.download,
                  ),
                  const SizedBox(height: 8),
                  SettingsTile(
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
                  SettingsTile(
                    icon: Icons.update,
                    title: 'Auto-Update Downloads',
                    subtitle: 'Automatically fetch new episodes',
                    trailing: Switch.adaptive(
                      value: _autoUpdate,
                      onChanged: (v) => setState(() => _autoUpdate = v),
                      activeTrackColor: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  const SettingsSectionTitle(
                    title: 'Notifications',
                    icon: Icons.notifications_none,
                  ),
                  const SizedBox(height: 8),
                  SettingsTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Push Notifications',
                    subtitle: 'Get notified for new episodes',
                    trailing: Switch.adaptive(
                      value: _notificationsEnabled,
                      onChanged: (v) =>
                          setState(() => _notificationsEnabled = v),
                      activeTrackColor: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  const SettingsSectionTitle(
                    title: 'About',
                    icon: Icons.info_outline,
                  ),
                  const SizedBox(height: 8),
                  const SettingsTile(
                    icon: Icons.code,
                    title: 'Version',
                    subtitle: '1.0.0',
                  ),
                  SettingsTile(
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
}
