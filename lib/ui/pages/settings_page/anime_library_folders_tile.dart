import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/shared/platform_paths.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';

class AnimeLibraryFoldersTile extends StatelessWidget {
  final List<String> folders;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<List<String>> onReorder;
  final String? searchQuery;

  const AnimeLibraryFoldersTile({
    super.key,
    required this.folders,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
    this.searchQuery,
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
          searchQuery: searchQuery,
          trailing: IconButton(
            tooltip: 'Add folder',
            onPressed: () => _pickFolder(context),
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

  Future<void> _pickFolder(BuildContext context) async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose anime library folder',
      initialDirectory: await _pickerInitialDirectory(),
    );
    if (selected != null && selected.trim().isNotEmpty) onAdd(selected);
  }

  Future<String?> _pickerInitialDirectory() async {
    for (final folder in folders) {
      final directory = Directory(folder);
      if (await directory.exists()) return directory.path;
    }
    final defaultDirectory = await defaultAnimeDownloadsRootDirectory();
    if (await defaultDirectory.exists()) return defaultDirectory.path;
    final parent = Directory(path.dirname(defaultDirectory.path));
    return await parent.exists() ? parent.path : null;
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
