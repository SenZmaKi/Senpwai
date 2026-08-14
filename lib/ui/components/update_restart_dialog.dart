import 'dart:io';

import 'package:flutter/material.dart';

class UpdateRestartDialog extends StatelessWidget {
  final int downloadCount;
  final int seedCount;

  const UpdateRestartDialog({
    super.key,
    required this.downloadCount,
    required this.seedCount,
  });

  @override
  Widget build(BuildContext context) {
    final total = downloadCount + seedCount;
    final action = Platform.isAndroid ? 'install the update' : 'restart';
    return AlertDialog(
      icon: const Icon(Icons.downloading_rounded),
      title: const Text('Transfers still running'),
      content: Text(
        '$total ${total == 1 ? 'transfer is' : 'transfers are'} still active. '
        'Continuing will cancel ${total == 1 ? 'it' : 'them'} before Senpwai '
        '$action. The prepared update can wait until you finish.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep downloading'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            Platform.isAndroid
                ? 'Cancel transfers and install'
                : 'Cancel transfers and restart',
          ),
        ),
      ],
    );
  }
}
