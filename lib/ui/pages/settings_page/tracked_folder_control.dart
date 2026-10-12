import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:senpwai/ui/components/toast.dart';

class TrackedFolderControl extends StatefulWidget {
  final String folder;
  final Future<void> Function(String) onChanged;

  const TrackedFolderControl({
    super.key,
    required this.folder,
    required this.onChanged,
  });

  @override
  State<TrackedFolderControl> createState() => _TrackedFolderControlState();
}

class _TrackedFolderControlState extends State<TrackedFolderControl> {
  bool _busy = false;

  Future<void> _pick() async {
    setState(() => _busy = true);
    try {
      final current = Directory(widget.folder);
      final selected = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose tracked download folder',
        initialDirectory: await current.exists() ? current.path : null,
      );
      if (!mounted || selected == null || selected.trim().isEmpty) return;
      await widget.onChanged(selected);
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          context,
          title: 'Couldn’t change folder',
          description: 'Try choosing the folder again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.folder,
    child: TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        foregroundColor: Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.65),
        alignment: Alignment.centerLeft,
      ),
      onPressed: _busy ? null : _pick,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _busy ? Icons.hourglass_top_rounded : Icons.folder_open_rounded,
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.folder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.edit_outlined, size: 14),
        ],
      ),
    ),
  );
}
