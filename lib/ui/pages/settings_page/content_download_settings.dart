import 'dart:async';

import 'package:flutter/material.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/ui/pages/settings_page/anime_library_folders_tile.dart';
import 'package:senpwai/ui/pages/settings_page/settings_controls.dart';
import 'package:senpwai/ui/pages/settings_page/settings_formatters.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';

class ContentDownloadSettings extends StatelessWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;
  final String? searchQuery;

  const ContentDownloadSettings({
    super.key,
    required this.settings,
    required this.notifier,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsGroupCard(
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
                onChanged: (value) =>
                    unawaited(notifier.setTitleLanguage(value)),
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
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value'),
                          ),
                        )
                        .toList(),
                onChanged: (value) =>
                    unawaited(notifier.setDefaultResolution(value)),
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
                    DropdownMenuItem(
                      value: value,
                      child: Text(value.toString()),
                    ),
                ],
                onChanged: (value) =>
                    unawaited(notifier.setDefaultAudioLanguage(value)),
              ),
            ),
            SettingsTile(
              icon: Icons.fast_forward_rounded,
              title: 'Skip Filler Episodes',
              subtitle:
                  'Automatically exclude pure filler episodes from downloads',
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
        ),
        SettingsGroupCard(
          title: 'Storage & Network Limit',
          icon: Icons.folder_special_outlined,
          description: 'Manage download destination folders and speed limit',
          searchQuery: searchQuery,
          searchTerms: [
            'Anime Library Folders add remove reorder folder directory path',
            ...settings.downloads.effectiveRootDirectories,
          ],
          children: [
            AnimeLibraryFoldersTile(
              folders: settings.downloads.effectiveRootDirectories,
              searchQuery: searchQuery,
              onAdd: (folder) =>
                  unawaited(notifier.addDownloadRootDirectory(folder)),
              onRemove: (folder) =>
                  unawaited(notifier.removeDownloadRootDirectory(folder)),
              onReorder: (folders) =>
                  unawaited(notifier.setDownloadRootDirectories(folders)),
            ),
            SettingsTile(
              icon: Icons.speed_rounded,
              title: 'HTTP Download Limit',
              subtitle: formatSpeedLimit(
                settings.downloads.maxDownloadBytesPerSecond,
              ),
              searchQuery: searchQuery,
              trailing: LimitSettingControl(
                mode: _speedLimitMode(
                  settings.downloads.maxDownloadBytesPerSecond,
                ),
                allowsDisabled: false,
                onModeChanged: (mode) => unawaited(
                  notifier.setHttpMaxDownloadBytesPerSecond(
                    mode == LimitMode.unlimited
                        ? 0
                        : _speedLimitForCustomValue(
                            settings.downloads.maxDownloadBytesPerSecond,
                          ),
                  ),
                ),
                valueField: NumberSettingField(
                  value: _megabytesForCustomValue(
                    settings.downloads.maxDownloadBytesPerSecond,
                  ),
                  unit: 'MB/s',
                  min: 1,
                  zeroValueModeShortcut: true,
                  onSubmitted: (value) => unawaited(
                    notifier.setHttpMaxDownloadBytesPerSecond(megabytes(value)),
                  ),
                ),
              ),
            ),
            SettingsTile(
              icon: Icons.low_priority_rounded,
              title: 'Active HTTP Downloads',
              subtitle: _queueLimitSubtitle(
                settings.downloads.maxActiveDownloads,
              ),
              searchQuery: searchQuery,
              trailing: LimitSettingControl(
                mode: _queueLimitMode(settings.downloads.maxActiveDownloads),
                onModeChanged: (mode) => unawaited(
                  notifier.setHttpMaxActiveDownloads(
                    _queueLimitForMode(
                      mode,
                      settings.downloads.maxActiveDownloads,
                    ),
                  ),
                ),
                valueField: NumberSettingField(
                  value: settings.downloads.maxActiveDownloads > 0
                      ? settings.downloads.maxActiveDownloads
                      : 1,
                  unit: 'active',
                  min: 1,
                  zeroValueModeShortcut: true,
                  onSubmitted: (value) =>
                      unawaited(notifier.setHttpMaxActiveDownloads(value)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

int _bytesToMegabytes(int bytes) => (bytes / (1024 * 1024)).round();

LimitMode _speedLimitMode(int value) =>
    value <= 0 ? LimitMode.unlimited : LimitMode.limited;

int _speedLimitForCustomValue(int value) => value > 0 ? value : megabytes(10);

int _megabytesForCustomValue(int bytes) =>
    _bytesToMegabytes(_speedLimitForCustomValue(bytes));

LimitMode _queueLimitMode(int value) => switch (value) {
  -1 => LimitMode.unlimited,
  0 => LimitMode.disabled,
  _ => LimitMode.limited,
};

int _queueLimitForMode(LimitMode mode, int current) => switch (mode) {
  LimitMode.disabled => 0,
  LimitMode.limited => current > 0 ? current : 1,
  LimitMode.unlimited => -1,
};

String _queueLimitSubtitle(int value) => switch (value) {
  -1 => 'Unlimited downloads',
  0 => 'HTTP downloads disabled',
  _ => 'Up to $value active downloads',
};
