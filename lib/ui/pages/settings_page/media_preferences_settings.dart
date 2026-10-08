import 'dart:async';

import 'package:flutter/material.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/ui/pages/settings_page/settings_controls.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';

class MediaPreferencesSettings extends StatelessWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;
  final String? searchQuery;

  const MediaPreferencesSettings({
    super.key,
    required this.settings,
    required this.notifier,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) => SettingsGroupCard(
    title: 'Media Preferences',
    icon: Icons.movie_filter_outlined,
    description: 'Default resolution, audio language, and title display',
    searchQuery: searchQuery,
    children: [
      SettingsTile(
        icon: Icons.language_rounded,
        title: 'Title Language',
        subtitle: 'Preferred title display with automatic fallbacks',
        searchQuery: searchQuery,
        trailing: SettingsDropdown<TitleLanguagePreference>(
          value: settings.content.titleLanguage,
          items: [
            for (final value in TitleLanguagePreference.values)
              DropdownMenuItem(value: value, child: Text(value.label)),
          ],
          onChanged: (value) => unawaited(notifier.setTitleLanguage(value)),
        ),
      ),
      SettingsTile(
        icon: Icons.high_quality_rounded,
        title: 'Default Resolution',
        subtitle: 'Initial resolution selected on anime pages',
        searchQuery: searchQuery,
        trailing: SettingsDropdown<Resolution>(
          value: settings.content.defaultResolution,
          items:
              const [
                    Resolution.res1080p,
                    Resolution.res720p,
                    Resolution.res480p,
                    Resolution.res360p,
                  ]
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text('$value')),
                  )
                  .toList(),
          onChanged: (value) => unawaited(notifier.setDefaultResolution(value)),
        ),
      ),
      SettingsTile(
        icon: Icons.record_voice_over_rounded,
        title: 'Default Audio',
        subtitle: 'Initial audio language selected on anime pages',
        searchQuery: searchQuery,
        trailing: SettingsDropdown<Language>(
          value: settings.content.defaultAudioLanguage,
          items: [
            for (final value in Language.values)
              DropdownMenuItem(value: value, child: Text(value.toString())),
          ],
          onChanged: (value) =>
              unawaited(notifier.setDefaultAudioLanguage(value)),
        ),
      ),
      SettingsTile(
        icon: Icons.record_voice_over_outlined,
        title: 'Allow Audio Fallback',
        subtitle:
            'Use another audio language when the selected one is unavailable. Turn off to skip those episodes.',
        searchQuery: searchQuery,
        trailing: AsyncSwitch(
          value: settings.content.allowAudioFallback,
          onChanged: notifier.setAllowAudioFallback,
        ),
      ),
      SettingsTile(
        icon: Icons.high_quality_outlined,
        title: 'Allow Quality Fallback',
        subtitle:
            'Use another resolution when the selected one is unavailable. Turn off to skip those episodes.',
        searchQuery: searchQuery,
        trailing: AsyncSwitch(
          value: settings.content.allowQualityFallback,
          onChanged: notifier.setAllowQualityFallback,
        ),
      ),
      SettingsTile(
        icon: Icons.fast_forward_rounded,
        title: 'Skip Filler Episodes',
        subtitle: 'Automatically exclude pure filler episodes from downloads',
        searchQuery: searchQuery,
        trailing: AsyncSwitch(
          value: settings.downloads.skipFillers,
          onChanged: notifier.setSkipFillers,
        ),
      ),
      SettingsTile(
        icon: Icons.visibility_off_outlined,
        title: 'Adult Content',
        subtitle: 'Show adult entries in AniList results',
        searchQuery: searchQuery,
        trailing: AsyncSwitch(
          value: settings.content.showAdultContent,
          onChanged: notifier.setShowAdultContent,
        ),
      ),
    ],
  );
}
