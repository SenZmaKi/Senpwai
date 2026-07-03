import 'dart:async';

import 'package:flutter/material.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/ui/pages/settings_page/settings_controls.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';

class TorrentAdvancedSettings extends StatelessWidget {
  final TorrentPreferences torrent;
  final AppSettingsNotifier notifier;

  const TorrentAdvancedSettings({
    super.key,
    required this.torrent,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AdvancedSwitch(
          icon: Icons.input_rounded,
          title: 'Incoming TCP',
          subtitle: 'Accept TCP peer connections',
          value: torrent.enableIncomingTcp,
          onChanged: (value) =>
              notifier.setTorrentAdvanced(enableIncomingTcp: value),
        ),
        _AdvancedSwitch(
          icon: Icons.waves_rounded,
          title: 'Incoming uTP',
          subtitle: 'Accept uTP peer connections',
          value: torrent.enableIncomingUtp,
          onChanged: (value) =>
              notifier.setTorrentAdvanced(enableIncomingUtp: value),
        ),
        _AdvancedSwitch(
          icon: Icons.output_rounded,
          title: 'Outgoing TCP',
          subtitle: 'Connect to peers over TCP',
          value: torrent.enableOutgoingTcp,
          onChanged: (value) =>
              notifier.setTorrentAdvanced(enableOutgoingTcp: value),
        ),
        _AdvancedSwitch(
          icon: Icons.swap_horiz_rounded,
          title: 'Outgoing uTP',
          subtitle: 'Connect to peers over uTP',
          value: torrent.enableOutgoingUtp,
          onChanged: (value) =>
              notifier.setTorrentAdvanced(enableOutgoingUtp: value),
        ),
        _AdvancedSwitch(
          icon: Icons.manage_search_rounded,
          title: 'Prefer Seeds',
          subtitle: 'Prefer seeding torrents when libtorrent auto-manages',
          value: torrent.autoManagePreferSeeds,
          onChanged: (value) =>
              notifier.setTorrentAdvanced(autoManagePreferSeeds: value),
        ),
        SettingsTile(
          icon: Icons.route_rounded,
          title: 'Proxy',
          subtitle: torrent.proxyMode.label,
          trailing: SettingsDropdown<TorrentProxyMode>(
            value: torrent.proxyMode,
            items: [
              for (final value in TorrentProxyMode.values)
                DropdownMenuItem(value: value, child: Text(value.label)),
            ],
            onChanged: (value) =>
                unawaited(notifier.setTorrentProxy(proxyMode: value)),
          ),
        ),
        if (torrent.proxyMode != TorrentProxyMode.none)
          ..._proxyServerControls(),
        if (torrent.proxyMode == TorrentProxyMode.socks5Password ||
            torrent.proxyMode == TorrentProxyMode.httpPassword)
          ..._proxyAuthControls(),
      ],
    );
  }

  List<Widget> _proxyServerControls() {
    return [
      SettingsTile(
        icon: Icons.dns_outlined,
        title: 'Proxy Host',
        subtitle: 'Hostname or IP address',
        trailing: TextSettingField(
          value: torrent.proxyHost,
          hintText: '127.0.0.1',
          onSubmitted: (value) =>
              unawaited(notifier.setTorrentProxy(proxyHost: value)),
        ),
      ),
      SettingsTile(
        icon: Icons.numbers_rounded,
        title: 'Proxy Port',
        subtitle: 'Proxy listener port',
        trailing: NumberSettingField(
          value: torrent.proxyPort,
          unit: 'port',
          max: 65535,
          onSubmitted: (value) =>
              unawaited(notifier.setTorrentProxy(proxyPort: value)),
        ),
      ),
    ];
  }

  List<Widget> _proxyAuthControls() {
    return [
      SettingsTile(
        icon: Icons.person_outline_rounded,
        title: 'Proxy Username',
        subtitle: 'Authentication username',
        trailing: TextSettingField(
          value: torrent.proxyUsername,
          onSubmitted: (value) =>
              unawaited(notifier.setTorrentProxy(proxyUsername: value)),
        ),
      ),
      SettingsTile(
        icon: Icons.password_rounded,
        title: 'Proxy Password',
        subtitle: 'Authentication password',
        trailing: TextSettingField(
          value: torrent.proxyPassword,
          obscureText: true,
          onSubmitted: (value) =>
              unawaited(notifier.setTorrentProxy(proxyPassword: value)),
        ),
      ),
    ];
  }
}

class _AdvancedSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Future<void> Function(bool value) onChanged;

  const _AdvancedSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: AsyncSwitch(value: value, onChanged: onChanged),
    );
  }
}
