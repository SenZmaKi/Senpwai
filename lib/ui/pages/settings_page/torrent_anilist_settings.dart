import 'dart:async';

import 'package:flutter/material.dart';
import 'package:senpwai/notifications/app_notification_service.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/ui/pages/settings_page/settings_controls.dart';
import 'package:senpwai/ui/pages/settings_page/settings_formatters.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';

class TorrentAnilistSettings extends StatelessWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;

  const TorrentAnilistSettings({
    super.key,
    required this.settings,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final torrent = settings.torrent;
    return Column(
      children: [
        SettingsTile(
          icon: Icons.download_for_offline_rounded,
          title: 'Torrent Download Limit',
          subtitle: formatSpeedLimit(torrent.maxDownloadBytesPerSecond),
          trailing: NumberSettingField(
            value: _bytesToMegabytes(torrent.maxDownloadBytesPerSecond),
            unit: 'MB/s',
            onSubmitted: (value) => unawaited(
              notifier.setTorrentMaxDownloadBytesPerSecond(megabytes(value)),
            ),
          ),
        ),
        SettingsTile(
          icon: Icons.upload_rounded,
          title: 'Torrent Upload Limit',
          subtitle: formatSpeedLimit(torrent.maxUploadBytesPerSecond),
          trailing: NumberSettingField(
            value: _bytesToMegabytes(torrent.maxUploadBytesPerSecond),
            unit: 'MB/s',
            onSubmitted: (value) => unawaited(
              notifier.setTorrentMaxUploadBytesPerSecond(megabytes(value)),
            ),
          ),
        ),
        _DiscoverySwitch(
          title: 'DHT',
          subtitle: 'Use distributed peer discovery',
          value: torrent.enableDht,
          onChanged: (value) => notifier.setTorrentDiscovery(enableDht: value),
        ),
        _DiscoverySwitch(
          title: 'Local Peer Discovery',
          subtitle: 'Find peers on the local network',
          value: torrent.enableLsd,
          onChanged: (value) => notifier.setTorrentDiscovery(enableLsd: value),
        ),
        _DiscoverySwitch(
          title: 'UPnP',
          subtitle: 'Ask routers to map torrent ports automatically',
          value: torrent.enableUpnp,
          onChanged: (value) => notifier.setTorrentDiscovery(enableUpnp: value),
        ),
        _DiscoverySwitch(
          title: 'NAT-PMP',
          subtitle: 'Use NAT-PMP for automatic port mapping',
          value: torrent.enableNatPmp,
          onChanged: (value) =>
              notifier.setTorrentDiscovery(enableNatPmp: value),
        ),
        SettingsTile(
          icon: Icons.share_rounded,
          title: 'Seed Ratio',
          subtitle: 'Available after persistent torrent sessions',
          trailing: const DisabledBadge(),
          enabled: false,
        ),
        SettingsTile(
          icon: Icons.timer_outlined,
          title: 'Seed Time',
          subtitle: 'Available after persistent torrent sessions',
          trailing: const DisabledBadge(),
          enabled: false,
        ),
        SettingsTile(
          icon: Icons.sync_rounded,
          title: 'Sync Watching to Tracked Anime',
          subtitle: 'Stored now; syncing waits for tracked-anime persistence',
          trailing: AsyncSwitch(
            value: settings.anilist.syncWatchingToTrackedAnime,
            onChanged: notifier.setSyncWatchingToTrackedAnime,
          ),
        ),
        SettingsTile(
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
          subtitle: _notificationsSubtitle(settings.notifications),
          trailing: AsyncSwitch(
            value: settings.notifications.enabled,
            onChanged: (enabled) => AppNotificationService.instance
                .setEnabledFromSettings(notifier: notifier, enabled: enabled),
          ),
        ),
        SettingsTile(
          icon: Icons.stacked_bar_chart_rounded,
          title: 'Download Notification Style',
          subtitle: _downloadNotificationStyleSubtitle(
            settings.notifications.downloadStyle,
          ),
          trailing: SettingsDropdown<DownloadNotificationStyle>(
            value: settings.notifications.downloadStyle,
            items: [
              for (final value in DownloadNotificationStyle.values)
                DropdownMenuItem(value: value, child: Text(value.label)),
            ],
            onChanged: (value) =>
                unawaited(notifier.setDownloadNotificationStyle(value)),
          ),
          enabled: settings.notifications.enabled,
        ),
        SettingsTile(
          icon: Icons.bug_report_outlined,
          title: 'Diagnostics',
          subtitle: 'Log-level controls are planned',
          trailing: const DisabledBadge(),
          enabled: false,
        ),
      ],
    );
  }
}

class _DiscoverySwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final Future<void> Function(bool value) onChanged;

  const _DiscoverySwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: Icons.hub_outlined,
      title: title,
      subtitle: subtitle,
      trailing: AsyncSwitch(value: value, onChanged: onChanged),
    );
  }
}

int _bytesToMegabytes(int bytes) => (bytes / (1024 * 1024)).round();

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
    DownloadNotificationStyle.batchSummary =>
      'Use one progress notification for the active batch',
    DownloadNotificationStyle.eachDownload =>
      'Show progress for every active item',
    DownloadNotificationStyle.completionOnly =>
      'Only notify when downloads finish or fail',
  };
}
