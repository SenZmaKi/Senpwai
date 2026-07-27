import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/tracking/models.dart';
import 'package:senpwai/tracking/notifier.dart';
import 'package:senpwai/ui/pages/settings_page/appearance_settings.dart';
import 'package:senpwai/ui/pages/settings_page/content_download_settings.dart';
import 'package:senpwai/ui/pages/settings_page/settings_search.dart';
import 'package:senpwai/ui/pages/settings_page/source_settings_section.dart';
import 'package:senpwai/ui/pages/settings_page/storage_settings_section.dart';
import 'package:senpwai/ui/pages/settings_page/torrent_settings_section.dart';
import 'package:senpwai/ui/pages/settings_page/tracking_settings_section.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

class SettingsSearchResults extends ConsumerWidget {
  final String query;
  final AppSettings settings;
  final AppSettingsNotifier notifier;
  final VoidCallback onClear;

  const SettingsSearchResults({
    super.key,
    required this.query,
    required this.settings,
    required this.notifier,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tracking = ref.watch(TrackingNotifier.provider);
    final hasResults = _hasSearchResults(settings, tracking);

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Search Results for "$query"',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Clear search'),
                ),
              ),
            ],
          ),
        ),
        if (hasResults) ...[
          AppearanceSettings(
            settings: settings,
            notifier: notifier,
            searchQuery: query,
          ),
          ContentDownloadSettings(
            settings: settings,
            notifier: notifier,
            searchQuery: query,
          ),
          TorrentSettingsSection(
            settings: settings,
            notifier: notifier,
            searchQuery: query,
          ),
          SourceSettingsSection(
            settings: settings,
            notifier: notifier,
            searchQuery: query,
          ),
          TrackingSettingsSection(
            settings: settings,
            notifier: notifier,
            searchQuery: query,
          ),
          StorageSettingsSection(
            settings: settings,
            notifier: notifier,
            searchQuery: query,
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 56),
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 40,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 12),
                Text(
                  'No settings found',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try a different name or keyword.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  bool _hasSearchResults(AppSettings settings, TrackingState tracking) {
    final torrent = settings.torrent;
    final notifications = settings.notifications;
    return settingsSearchMatches(query, [
      'Theme Style customize brightness mode active color theme',
      'Brightness light dark system Color Palette',
      for (final preset in SenpwaiThemePreset.values) preset.label,
      'Typography custom Google Fonts headers body text Display Font Body Font',
      settings.appearance.displayFontFamily,
      settings.appearance.bodyFontFamily,
      'Card Layout anime card style Home Search poster landscape table grid list',
      'Media Preferences default resolution audio language title display',
      'Title Language preferred title display automatic fallbacks',
      'Default Resolution initial resolution selected anime pages',
      'Default Audio initial audio language selected anime pages',
      'Skip Filler Episodes automatically exclude filler from downloads',
      'Adult Content show adult entries AniList results',
      'Storage Network Limit manage download destination folders speed limit',
      'Anime Library Folders add remove reorder',
      ...settings.downloads.effectiveRootDirectories,
      'HTTP Download Limit ${settings.downloads.maxDownloadBytesPerSecond}',
      'Bandwidth Queue Limits upload download speeds maximum parallel downloads',
      'Torrent Download Limit ${torrent.maxDownloadBytesPerSecond}',
      'Torrent Upload Limit ${torrent.maxUploadBytesPerSecond}',
      'Active Torrent Downloads episodes at once ${torrent.maxActiveDownloads}',
      'Active Seeds maximum active seeding torrents ${torrent.maxActiveSeeds}',
      'Seeding Rules ratio duration criteria before seeding stops',
      'Seed Ratio upload before stopping ${torrent.seedRatioLimit}',
      'Seed Time minimum seeding time ${torrent.seedTimeLimitMinutes}',
      'Network Discovery ports peer connection limits discovery protocols',
      'Torrent Port incoming peer listener ${torrent.torrentPort}',
      'Maximum Connections peer connection cap ${torrent.maxConnections}',
      'DHT Distributed Hash Table decentralized peer discovery',
      'Local Peer Discovery LSD local network',
      'UPnP Port Mapping routers automatically',
      'NAT-PMP Port Mapping',
      'Encryption Privacy peer encryption client identification',
      'Peer Encryption ${torrent.encryptionMode.label}',
      'Anonymous Mode hide client identifying extension data',
      'Advanced Protocol Proxy TCP uTP transport preferences configuration',
      'Incoming TCP Incoming uTP Outgoing TCP Outgoing uTP Prefer Seeds',
      'Proxy Host Port Username Password ${torrent.proxyMode.label}',
      'Provider Priority Activation drag reorder source toggle enabled disabled',
      for (final source in settings.sources.priority) source.label,
      'Nyaa Search Filtering default filters sorting torrent searches',
      'Exact Episode Only Same Season Only Manual Sort Order Minimum Seeders',
      settings.sources.nyaaDefaultFilters.sort.label,
      'AniList Account profile username log in log out connected',
      'Tracked Anime Auto-Downloader monitors releases downloads new episodes',
      'Check interval Check now No tracked anime',
      for (final tracked in tracking.trackedAnime) ...[
        tracked.animeSnapshot.title.display,
        tracked.downloadFolder,
        tracked.resolution.toString(),
        tracked.language.toString(),
        if (tracked.preferredSource != null) tracked.preferredSource!.label,
        if (tracked.lastError != null) tracked.lastError!,
      ],
      'Notifications app status updates download completion alerts',
      'System Notifications ${notifications.enabled ? 'enabled' : 'disabled'}',
      'Download Notification Style ${notifications.downloadStyle.label}',
      'Storage Memory Cache manage cache limits clear disk usage',
      'Image Cache Limit HTTP Cache Age',
      'Clear Image Cache Clear HTTP Cache Clear Cloudflare Sessions',
      'Clear App Cache Sessions',
      'About Senpwai Version 1.0.0 third party software Licenses open source',
    ]);
  }
}
