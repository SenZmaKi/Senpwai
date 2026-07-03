import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/ui/pages/settings_page/appearance_settings.dart';
import 'package:senpwai/ui/pages/settings_page/content_download_settings.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';
import 'package:senpwai/ui/pages/settings_page/source_settings_section.dart';
import 'package:senpwai/ui/pages/settings_page/storage_settings_section.dart';
import 'package:senpwai/ui/pages/settings_page/torrent_anilist_settings.dart';
import 'package:senpwai/ui/pages/settings_page/tracking_settings_section.dart';
import 'package:senpwai/ui/shared/responsive.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(AppSettingsNotifier.provider);
    final notifier = ref.read(AppSettingsNotifier.provider.notifier);
    final pad = horizontalPadding(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 24, pad, 32),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SettingsSectionTitle(
                      title: 'Appearance',
                      icon: Icons.palette_rounded,
                    ),
                    const SizedBox(height: 12),
                    AppearanceSettings(settings: settings, notifier: notifier),
                    const SizedBox(height: 24),
                    const SettingsSectionTitle(
                      title: 'Content and Downloads',
                      icon: Icons.tune_rounded,
                    ),
                    const SizedBox(height: 8),
                    ContentDownloadSettings(
                      settings: settings,
                      notifier: notifier,
                    ),
                    const SizedBox(height: 24),
                    const SettingsSectionTitle(
                      title: 'Sources',
                      icon: Icons.source_rounded,
                    ),
                    const SizedBox(height: 8),
                    SourceSettingsSection(
                      settings: settings,
                      notifier: notifier,
                    ),
                    const SizedBox(height: 24),
                    const SettingsSectionTitle(
                      title: 'Torrent and AniList',
                      icon: Icons.hub_rounded,
                    ),
                    const SizedBox(height: 8),
                    TorrentAnilistSettings(
                      settings: settings,
                      notifier: notifier,
                    ),
                    const SizedBox(height: 24),
                    const SettingsSectionTitle(
                      title: 'Tracked Anime',
                      icon: Icons.radar_rounded,
                    ),
                    const SizedBox(height: 8),
                    const TrackingSettingsSection(),
                    const SizedBox(height: 24),
                    const SettingsSectionTitle(
                      title: 'Storage',
                      icon: Icons.storage_rounded,
                    ),
                    const SizedBox(height: 8),
                    StorageSettingsSection(
                      settings: settings,
                      notifier: notifier,
                    ),
                    const SizedBox(height: 24),
                    const SettingsSectionTitle(
                      title: 'About',
                      icon: Icons.info_outline_rounded,
                    ),
                    const SizedBox(height: 8),
                    const SettingsTile(
                      icon: Icons.code_rounded,
                      title: 'Version',
                      subtitle: '1.0.0',
                    ),
                    SettingsTile(
                      icon: Icons.description_outlined,
                      title: 'Licenses',
                      subtitle: 'View open source licenses',
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
              ),
            ),
          ),
        ),
      ],
    );
  }
}
