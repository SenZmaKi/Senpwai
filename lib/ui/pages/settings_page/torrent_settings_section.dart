import 'dart:async';

import 'package:flutter/material.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/ui/pages/settings_page/settings_controls.dart';
import 'package:senpwai/ui/pages/settings_page/settings_formatters.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';
import 'package:senpwai/ui/pages/settings_page/torrent_advanced_settings.dart';

class TorrentSettingsSection extends StatelessWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;
  final String? searchQuery;

  const TorrentSettingsSection({
    super.key,
    required this.settings,
    required this.notifier,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final torrent = settings.torrent;
    return Column(
      children: [
        SettingsGroupCard(
          title: 'Bandwidth & Queue Limits',
          icon: Icons.speed_rounded,
          description:
              'Control upload/download speeds and maximum parallel downloads',
          searchQuery: searchQuery,
          children: [
            SettingsTile(
              icon: Icons.download_for_offline_rounded,
              title: 'Torrent Download Limit',
              subtitle: formatSpeedLimit(torrent.maxDownloadBytesPerSecond),
              searchQuery: searchQuery,
              trailing: NumberSettingField(
                value: _bytesToMegabytes(torrent.maxDownloadBytesPerSecond),
                unit: 'MB/s',
                onSubmitted: (value) => unawaited(
                  notifier.setTorrentMaxDownloadBytesPerSecond(
                    megabytes(value),
                  ),
                ),
              ),
            ),
            SettingsTile(
              icon: Icons.upload_rounded,
              title: 'Torrent Upload Limit',
              subtitle: formatSpeedLimit(torrent.maxUploadBytesPerSecond),
              searchQuery: searchQuery,
              trailing: NumberSettingField(
                value: _bytesToMegabytes(torrent.maxUploadBytesPerSecond),
                unit: 'MB/s',
                onSubmitted: (value) => unawaited(
                  notifier.setTorrentMaxUploadBytesPerSecond(megabytes(value)),
                ),
              ),
            ),
            SettingsTile(
              icon: Icons.low_priority_rounded,
              title: 'Active Torrent Downloads',
              subtitle: 'Start this many torrent episodes at once',
              searchQuery: searchQuery,
              trailing: NumberSettingField(
                value: torrent.maxActiveDownloads,
                unit: 'active',
                min: 1,
                onSubmitted: (value) => unawaited(
                  notifier.setTorrentLimits(maxActiveDownloads: value),
                ),
              ),
            ),
            SettingsTile(
              icon: Icons.upload_file_rounded,
              title: 'Active Seeds',
              subtitle: 'Maximum active seeding torrents',
              searchQuery: searchQuery,
              trailing: NumberSettingField(
                value: torrent.maxActiveSeeds,
                unit: 'seeds',
                min: 1,
                onSubmitted: (value) =>
                    unawaited(notifier.setTorrentLimits(maxActiveSeeds: value)),
              ),
            ),
          ],
        ),
        SettingsGroupCard(
          title: 'Seeding Rules',
          icon: Icons.share_rounded,
          description: 'Ratio and duration criteria before seeding stops',
          searchQuery: searchQuery,
          children: [
            SettingsTile(
              icon: Icons.share_rounded,
              title: 'Seed Ratio',
              subtitle:
                  '${_formatSeedRatio(torrent.seedRatioLimit)}x upload before stopping',
              searchQuery: searchQuery,
              trailing: DecimalSettingField(
                value: torrent.seedRatioLimit / 100,
                unit: 'x',
                fractionDigits: 1,
                onSubmitted: (value) => unawaited(
                  notifier.setTorrentLimits(
                    seedRatioLimit: (value * 100).round(),
                  ),
                ),
              ),
            ),
            SettingsTile(
              icon: Icons.timer_outlined,
              title: 'Seed Time',
              subtitle: _minutesSubtitle(torrent.seedTimeLimitMinutes),
              searchQuery: searchQuery,
              trailing: NumberSettingField(
                value: torrent.seedTimeLimitMinutes,
                unit: 'min',
                onSubmitted: (value) => unawaited(
                  notifier.setTorrentLimits(seedTimeLimitMinutes: value),
                ),
              ),
            ),
          ],
        ),
        SettingsGroupCard(
          title: 'Network & Discovery',
          icon: Icons.hub_outlined,
          description: 'Ports, peer connection limits, and discovery protocols',
          searchQuery: searchQuery,
          children: [
            SettingsTile(
              icon: Icons.settings_ethernet_rounded,
              title: 'Torrent Port',
              subtitle: 'Incoming peer listener port',
              searchQuery: searchQuery,
              trailing: NumberSettingField(
                value: torrent.torrentPort,
                unit: 'port',
                max: 65535,
                onSubmitted: (value) =>
                    unawaited(notifier.setTorrentLimits(torrentPort: value)),
              ),
            ),
            SettingsTile(
              icon: Icons.device_hub_rounded,
              title: 'Maximum Connections',
              subtitle: 'Peer connection cap per torrent session',
              searchQuery: searchQuery,
              trailing: NumberSettingField(
                value: torrent.maxConnections,
                unit: 'peers',
                min: 1,
                onSubmitted: (value) =>
                    unawaited(notifier.setTorrentLimits(maxConnections: value)),
              ),
            ),
            SettingsTile(
              icon: Icons.hub_outlined,
              title: 'DHT (Distributed Hash Table)',
              subtitle: 'Use decentralized peer discovery',
              searchQuery: searchQuery,
              trailing: AsyncSwitch(
                value: torrent.enableDht,
                onChanged: (value) =>
                    notifier.setTorrentDiscovery(enableDht: value),
              ),
            ),
            SettingsTile(
              icon: Icons.wifi_tethering_rounded,
              title: 'Local Peer Discovery (LSD)',
              subtitle: 'Find peers on your local network',
              searchQuery: searchQuery,
              trailing: AsyncSwitch(
                value: torrent.enableLsd,
                onChanged: (value) =>
                    notifier.setTorrentDiscovery(enableLsd: value),
              ),
            ),
            SettingsTile(
              icon: Icons.router_rounded,
              title: 'UPnP Port Mapping',
              subtitle: 'Ask routers to map torrent ports automatically',
              searchQuery: searchQuery,
              trailing: AsyncSwitch(
                value: torrent.enableUpnp,
                onChanged: (value) =>
                    notifier.setTorrentDiscovery(enableUpnp: value),
              ),
            ),
            SettingsTile(
              icon: Icons.alt_route_rounded,
              title: 'NAT-PMP Port Mapping',
              subtitle: 'Use NAT-PMP for port mapping',
              searchQuery: searchQuery,
              trailing: AsyncSwitch(
                value: torrent.enableNatPmp,
                onChanged: (value) =>
                    notifier.setTorrentDiscovery(enableNatPmp: value),
              ),
            ),
          ],
        ),
        SettingsGroupCard(
          title: 'Encryption & Privacy',
          icon: Icons.security_rounded,
          description: 'Peer encryption settings and client identification',
          searchQuery: searchQuery,
          children: [
            SettingsTile(
              icon: Icons.enhanced_encryption_rounded,
              title: 'Peer Encryption',
              subtitle: _encryptionSubtitle(torrent.encryptionMode),
              searchQuery: searchQuery,
              trailing: SettingsDropdown<TorrentEncryptionMode>(
                value: torrent.encryptionMode,
                items: [
                  for (final value in TorrentEncryptionMode.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) => unawaited(
                  notifier.setTorrentAdvanced(encryptionMode: value),
                ),
              ),
            ),
            SettingsTile(
              icon: Icons.visibility_off_outlined,
              title: 'Anonymous Mode',
              subtitle: 'Hide client-identifying extension data',
              searchQuery: searchQuery,
              trailing: AsyncSwitch(
                value: torrent.anonymousMode,
                onChanged: (value) =>
                    notifier.setTorrentAdvanced(anonymousMode: value),
              ),
            ),
          ],
        ),
        SettingsGroupCard(
          title: 'Advanced Protocol & Proxy',
          icon: Icons.tune_rounded,
          description: 'TCP/uTP transport preferences and proxy configuration',
          searchQuery: searchQuery,
          searchTerms: const [
            'Incoming TCP accept peer connections',
            'Incoming uTP accept peer connections',
            'Outgoing TCP connect peers',
            'Outgoing uTP connect peers',
            'Prefer Seeds seeding torrents auto manages',
            'Proxy host port username password authentication',
          ],
          children: [
            TorrentAdvancedSettings(
              torrent: torrent,
              notifier: notifier,
              searchQuery: searchQuery,
            ),
          ],
        ),
      ],
    );
  }
}

int _bytesToMegabytes(int bytes) => (bytes / (1024 * 1024)).round();

String _formatSeedRatio(int scaledRatio) {
  final ratio = scaledRatio / 100;
  return ratio.toStringAsFixed(ratio.truncateToDouble() == ratio ? 0 : 1);
}

String _minutesSubtitle(int minutes) {
  if (minutes == 0) return 'No minimum seeding time';
  if (minutes < 60) return '$minutes minutes';
  final hours = minutes / 60;
  return '${hours.toStringAsFixed(hours.truncateToDouble() == hours ? 0 : 1)} hours';
}

String _encryptionSubtitle(TorrentEncryptionMode mode) {
  return switch (mode) {
    TorrentEncryptionMode.enabled => 'Prefer encrypted peers when available',
    TorrentEncryptionMode.forced => 'Only use encrypted peer connections',
    TorrentEncryptionMode.disabled => 'Allow unencrypted peer connections',
  };
}
