import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/ui/pages/settings_page/settings_controls.dart';
import 'package:senpwai/ui/pages/settings_page/settings_formatters.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';

class ContentDownloadSettings extends StatelessWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;

  const ContentDownloadSettings({
    super.key,
    required this.settings,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsTile(
          icon: Icons.language_rounded,
          title: 'Title Language',
          subtitle: 'Preferred title display with automatic fallbacks',
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
          icon: Icons.visibility_off_outlined,
          title: 'Adult Content',
          subtitle: 'Show adult entries in AniList results',
          trailing: AsyncSwitch(
            value: settings.content.showAdultContent,
            onChanged: notifier.setShowAdultContent,
          ),
        ),
        SettingsTile(
          icon: Icons.high_quality_rounded,
          title: 'Default Resolution',
          subtitle: 'Initial resolution selected on anime pages',
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
            onChanged: (value) =>
                unawaited(notifier.setDefaultResolution(value)),
          ),
        ),
        SettingsTile(
          icon: Icons.record_voice_over_rounded,
          title: 'Default Audio',
          subtitle: 'Initial audio language selected on anime pages',
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
          icon: Icons.folder_outlined,
          title: 'Download Root',
          subtitle:
              settings.downloads.defaultRootDirectory ?? 'Default Anime folder',
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => unawaited(_pickDownloadRoot(context)),
        ),
        SettingsTile(
          icon: Icons.speed_rounded,
          title: 'HTTP Download Limit',
          subtitle: formatSpeedLimit(
            settings.downloads.maxDownloadBytesPerSecond,
          ),
          trailing: NumberSettingField(
            value: _bytesToMegabytes(
              settings.downloads.maxDownloadBytesPerSecond,
            ),
            unit: 'MB/s',
            onSubmitted: (value) => unawaited(
              notifier.setHttpMaxDownloadBytesPerSecond(megabytes(value)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDownloadRoot(BuildContext context) async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose default download folder',
    );
    if (selected != null && selected.trim().isNotEmpty) {
      await notifier.setDefaultDownloadRoot(selected);
    }
  }
}

int _bytesToMegabytes(int bytes) => (bytes / (1024 * 1024)).round();
