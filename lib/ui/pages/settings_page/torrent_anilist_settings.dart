import 'package:flutter/material.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/ui/pages/settings_page/torrent_settings_section.dart';

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
    return TorrentSettingsSection(settings: settings, notifier: notifier);
  }
}
