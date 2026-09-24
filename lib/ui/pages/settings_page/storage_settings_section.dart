import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/notifications/app_notification_service.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/ui/components/confirm_dialog.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/pages/settings_page/settings_controls.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';

class StorageSettingsSection extends ConsumerStatefulWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;
  final String? searchQuery;

  const StorageSettingsSection({
    super.key,
    required this.settings,
    required this.notifier,
    this.searchQuery,
  });

  @override
  ConsumerState<StorageSettingsSection> createState() =>
      _StorageSettingsSectionState();
}

class _StorageSettingsSectionState
    extends ConsumerState<StorageSettingsSection> {
  @override
  Widget build(BuildContext context) {
    final sq = widget.searchQuery;
    final notifications = widget.settings.notifications;
    return Column(
      children: [
        SettingsGroupCard(
          title: 'Notifications',
          icon: Icons.notifications_outlined,
          description: 'App status updates and download completion alerts',
          searchQuery: sq,
          children: [
            SettingsTile(
              icon: Icons.notifications_none_rounded,
              title: 'System Notifications',
              subtitle: _notificationsSubtitle(notifications),
              searchQuery: sq,
              trailing: AsyncSwitch(
                value: notifications.enabled,
                onChanged: (enabled) =>
                    AppNotificationService.instance.setEnabledFromSettings(
                      notifier: widget.notifier,
                      enabled: enabled,
                    ),
              ),
            ),
            SettingsTile(
              icon: Icons.stacked_bar_chart_rounded,
              title: 'Download Notification Style',
              subtitle: _downloadNotificationStyleSubtitle(
                notifications.downloadStyle,
              ),
              searchQuery: sq,
              trailing: SettingsDropdown<DownloadNotificationStyle>(
                value: notifications.downloadStyle,
                items: [
                  for (final value in DownloadNotificationStyle.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) => unawaited(
                  widget.notifier.setDownloadNotificationStyle(value),
                ),
              ),
              enabled: notifications.enabled,
            ),
            if (Platform.isWindows)
              SettingsTile(
                icon: Icons.download_rounded,
                title: 'Windows Download Progress Notification',
                subtitle:
                    'Show live progress; taskbar progress stays on either way',
                searchQuery: sq,
                trailing: AsyncSwitch(
                  value: notifications.showWindowsProgressNotification,
                  onChanged: widget.notifier.setShowWindowsProgressNotification,
                ),
                enabled: notifications.enabled,
              ),
          ],
        ),
        SettingsGroupCard(
          title: 'Reset Settings',
          icon: Icons.restart_alt_rounded,
          description: 'Restore Senpwai preferences to their defaults',
          searchQuery: sq,
          children: [
            SettingsTile(
              icon: Icons.restart_alt_rounded,
              title: 'Reset All Settings',
              subtitle: 'Keep downloads, library, AniList account, and cache',
              keywords: 'restore defaults proxy credentials preferences',
              searchQuery: sq,
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => unawaited(_confirmAndResetSettings()),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmAndResetSettings() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Reset all settings?',
      message:
          'This restores settings to their defaults and disables the torrent proxy. Downloads, library, AniList account, saved proxy credentials, and cache are kept.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!confirmed) return;
    await widget.notifier.resetToDefaults();
    if (!mounted) return;
    AppToast.showInfo(context, title: 'Settings reset');
  }
}

String _notificationsSubtitle(NotificationPreferences notifications) {
  if (!notifications.enabled) {
    return notifications.permissionDenied
        ? 'Disabled after permission was denied'
        : 'Disabled';
  }
  return 'Download progress and status updates';
}

String _downloadNotificationStyleSubtitle(DownloadNotificationStyle style) =>
    switch (style) {
      DownloadNotificationStyle.batchCompletion =>
        'Show one result when a batch finishes',
      DownloadNotificationStyle.episodeCompletion =>
        'Show batch progress, then episode results',
    };
