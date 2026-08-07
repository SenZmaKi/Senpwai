import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/notifications/app_notification_service.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/persistence/app_persistence.dart';
import 'package:senpwai/ui/components/confirm_dialog.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/pages/settings_page/settings_controls.dart';
import 'package:senpwai/ui/pages/settings_page/settings_formatters.dart';
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
  late Future<AppStorageUsage> _usageFuture = _loadUsage();
  int _httpCacheAgeResetToken = 0;

  Future<AppStorageUsage> _loadUsage() =>
      calculateAppStorageUsage(AppPersistence.paths);

  void _refresh() {
    setState(() {
      _usageFuture = _loadUsage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sq = widget.searchQuery;
    return FutureBuilder<AppStorageUsage>(
      future: _usageFuture,
      builder: (context, snapshot) {
        final usage = snapshot.data;
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
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
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
                      onChanged: (show) => widget.notifier
                          .setShowWindowsProgressNotification(show),
                    ),
                    enabled: notifications.enabled,
                  ),
              ],
            ),
            SettingsGroupCard(
              title: 'Storage & Memory Cache',
              icon: Icons.storage_rounded,
              description: 'Manage cache limits and clear disk usage',
              searchQuery: sq,
              children: [
                SettingsTile(
                  icon: Icons.image_outlined,
                  title: 'Image Cache Limit',
                  subtitle:
                      '${_imageCacheLimitLabel(widget.settings.storage.imageCacheMaxBytes)} · Usage: ${_size(usage?.imageCacheBytes)}',
                  searchQuery: sq,
                  trailing: NumberSettingField(
                    value: _bytesToMegabytes(
                      widget.settings.storage.imageCacheMaxBytes,
                    ),
                    min: 0,
                    unit: 'MB',
                    onSubmitted: (value) => unawaited(
                      widget.notifier.setImageCacheMaxBytes(megabytes(value)),
                    ),
                  ),
                ),
                SettingsTile(
                  icon: Icons.http_rounded,
                  title: 'HTTP Cache Age',
                  subtitle: 'Usage: ${_size(usage?.httpCacheBytes)}',
                  searchQuery: sq,
                  trailing: NumberSettingField(
                    value: widget.settings.storage.httpCacheMaxAge.inHours,
                    min: -999999,
                    allowNegative: true,
                    resetToken: _httpCacheAgeResetToken,
                    unit: 'hours',
                    onSubmitted: (value) => unawaited(_setHttpCacheAge(value)),
                  ),
                ),
                SettingsTile(
                  icon: Icons.delete_sweep_outlined,
                  title: 'Clear Image Cache',
                  subtitle: _size(usage?.imageCacheBytes),
                  searchQuery: sq,
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => unawaited(
                    _confirmAndRun(
                      title: 'Clear image cache?',
                      message:
                          'Cached covers and banners will be downloaded again.',
                      action: AppPersistence.clearImageCache,
                    ),
                  ),
                ),
                SettingsTile(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Clear HTTP Cache',
                  subtitle: _size(usage?.httpCacheBytes),
                  searchQuery: sq,
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => unawaited(
                    _confirmAndRun(
                      title: 'Clear HTTP cache?',
                      message: 'Cached network responses will be removed.',
                      action: AppPersistence.clearHttpCache,
                    ),
                  ),
                ),
                SettingsTile(
                  icon: Icons.cloud_off_outlined,
                  title: 'Clear Cloudflare Sessions',
                  subtitle: _size(usage?.cloudflareSessionBytes),
                  searchQuery: sq,
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => unawaited(
                    _confirmAndRun(
                      title: 'Clear Cloudflare sessions?',
                      message:
                          'Cloudflare cookies and bypass sessions will be removed.',
                      action: AppPersistence.clearNetworkSession,
                    ),
                  ),
                ),
                SettingsTile(
                  icon: Icons.layers_clear_outlined,
                  title: 'Clear App Cache & Sessions',
                  subtitle: _size(usage?.appCacheAndSessionBytes),
                  searchQuery: sq,
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => unawaited(
                    _confirmAndRun(
                      title: 'Clear app cache and sessions?',
                      message:
                          'This keeps settings, AniList login, and downloaded anime.',
                      action: AppPersistence.clearAppCacheAndSessions,
                    ),
                  ),
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
                  subtitle:
                      'Keep downloads, library, AniList account, and cache',
                  keywords: 'restore defaults proxy credentials preferences',
                  searchQuery: sq,
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => unawaited(_confirmAndResetSettings()),
                ),
              ],
            ),
            SettingsGroupCard(
              title: 'About Senpwai',
              icon: Icons.info_outline_rounded,
              description:
                  'Version information and third-party software licenses',
              searchQuery: sq,
              children: [
                SettingsTile(
                  icon: Icons.code_rounded,
                  title: 'Version',
                  subtitle: '1.0.0',
                  searchQuery: sq,
                ),
                SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Licenses',
                  subtitle: 'View open source licenses',
                  searchQuery: sq,
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'Senpwai',
                      applicationVersion: '1.0.0',
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndRun({
    required String title,
    required String message,
    required Future<void> Function() action,
  }) async {
    final confirmed = await showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!confirmed) return;
    await action();
    if (!mounted) return;
    _refresh();
    AppToast.showInfo(context, title: 'Storage cleared');
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
    AppToast.showInfo(context, title: 'Settings reset to defaults');
  }

  String _size(int? bytes) =>
      bytes == null ? 'Calculating...' : formatBytes(bytes);

  Future<void> _setHttpCacheAge(int hours) async {
    final wasReset = await widget.notifier.setHttpCacheMaxAge(
      Duration(hours: hours),
    );
    if (!mounted || !wasReset) return;
    setState(() => _httpCacheAgeResetToken++);
    AppToast.showWarning(
      context,
      title: 'Cache age reset',
      description: 'HTTP cache age must be greater than zero hours.',
    );
  }
}

int _bytesToMegabytes(int bytes) => (bytes / (1024 * 1024)).round();

String _imageCacheLimitLabel(int bytes) =>
    bytes == 0 ? 'Unlimited' : 'Limit: ${formatBytes(bytes)}';

String _notificationsSubtitle(NotificationPreferences notifications) {
  if (!notifications.enabled) {
    return notifications.permissionDenied
        ? 'Disabled after permission was denied'
        : 'Disabled';
  }
  return 'Download progress and status updates';
}

String _downloadNotificationStyleSubtitle(DownloadNotificationStyle style) {
  return switch (style) {
    DownloadNotificationStyle.batchCompletion =>
      'Show one result when a batch finishes',
    DownloadNotificationStyle.episodeCompletion =>
      'Show batch progress, then episode results',
  };
}
