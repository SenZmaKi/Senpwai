import 'package:flutter/material.dart';

/// Small reusable "Are you sure?" confirmation dialog.
/// Returns true when the user confirms, false (or null) otherwise.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final theme = Theme.of(context);
  final accent = destructive
      ? theme.colorScheme.error
      : theme.colorScheme.primary;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(
              destructive
                  ? Icons.warning_amber_rounded
                  : Icons.help_outline_rounded,
              color: accent,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: accent),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result == true;
}
