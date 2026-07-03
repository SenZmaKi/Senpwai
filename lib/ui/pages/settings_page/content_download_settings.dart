import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/platform_paths.dart';
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
        _AnimeLibraryFoldersTile(
          folders: settings.downloads.effectiveRootDirectories,
          onAdd: () => unawaited(_addAnimeLibraryFolder(context)),
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

  Future<void> _addAnimeLibraryFolder(BuildContext context) async {
    final initialDirectory = await _libraryPickerInitialDirectory(
      settings.downloads.effectiveRootDirectories,
    );
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose anime library folder',
      initialDirectory: initialDirectory,
    );
    if (selected != null && selected.trim().isNotEmpty) {
      await notifier.addDownloadRootDirectory(selected);
    }
  }
}

int _bytesToMegabytes(int bytes) => (bytes / (1024 * 1024)).round();

Future<String?> _libraryPickerInitialDirectory(List<String> folders) async {
  for (final folder in folders) {
    final directory = Directory(folder);
    if (await directory.exists()) return directory.path;
  }
  final defaultDirectory = await defaultAnimeDownloadsRootDirectory();
  if (await defaultDirectory.exists()) return defaultDirectory.path;
  final parent = Directory(path.dirname(defaultDirectory.path));
  return await parent.exists() ? parent.path : null;
}

class _AnimeLibraryFoldersTile extends StatelessWidget {
  final List<String> folders;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<List<String>> onReorder;

  const _AnimeLibraryFoldersTile({
    required this.folders,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = folders.isEmpty
        ? 'Default Anime folder'
        : folders.length == 1
        ? folders.first
        : '${folders.length} folders, searched in order';
    return Column(
      children: [
        SettingsTile(
          icon: Icons.video_library_outlined,
          title: 'Anime Library Folders',
          subtitle: subtitle,
          trailing: IconButton(
            tooltip: 'Add folder',
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 20),
          ),
        ),
        if (folders.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 38, right: 4, bottom: 8),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              physics: const NeverScrollableScrollPhysics(),
              proxyDecorator: (child, _, _) => Material(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                elevation: 6,
                child: child,
              ),
              itemCount: folders.length,
              onReorder: _handleReorder,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return _AnimeLibraryFolderRow(
                  key: ValueKey(folder),
                  index: index,
                  folder: folder,
                  onRemove: folders.length > 1 ? () => onRemove(folder) : null,
                  textStyle: theme.textTheme.bodySmall,
                );
              },
            ),
          ),
      ],
    );
  }

  void _handleReorder(int oldIndex, int newIndex) {
    final reordered = [...folders];
    if (oldIndex < newIndex) newIndex -= 1;
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    onReorder(reordered);
  }
}

class _AnimeLibraryFolderRow extends StatelessWidget {
  final int index;
  final String folder;
  final VoidCallback? onRemove;
  final TextStyle? textStyle;

  const _AnimeLibraryFolderRow({
    super.key,
    required this.index,
    required this.folder,
    required this.onRemove,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.folder_outlined,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: folder,
              child: Text(
                '${path.basename(folder)}  $folder',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: onRemove == null
                ? 'At least one folder is required'
                : 'Remove folder',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 16),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
