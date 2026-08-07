import 'package:flutter/material.dart';

enum DesktopExitChoice { quit, minimizeToTray }

class DesktopExitDialog extends StatelessWidget {
  final int downloadCount;
  final int seedCount;

  const DesktopExitDialog({
    super.key,
    required this.downloadCount,
    required this.seedCount,
  });

  @override
  Widget build(BuildContext context) {
    final activities = [
      if (downloadCount > 0)
        '$downloadCount ${downloadCount == 1 ? 'download' : 'downloads'} in progress',
      if (seedCount > 0)
        '$seedCount ${seedCount == 1 ? 'torrent' : 'torrents'} seeding',
    ];
    return AlertDialog(
      title: const Text('Transfers still running'),
      content: Text('${activities.join(' and ')}. Quitting will stop them.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(DesktopExitChoice.minimizeToTray),
          child: const Text('Minimize to tray'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(DesktopExitChoice.quit),
          child: const Text('Quit'),
        ),
      ],
    );
  }
}
