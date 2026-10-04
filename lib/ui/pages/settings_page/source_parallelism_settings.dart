import 'dart:async';

import 'package:flutter/material.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/ui/pages/anime_page/anime_source_ui.dart';
import 'package:senpwai/ui/pages/settings_page/settings_controls.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';

class SourceParallelismSettings extends StatelessWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;
  final String? searchQuery;

  const SourceParallelismSettings({
    super.key,
    required this.settings,
    required this.notifier,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final sources = settings.sources;
    return SettingsGroupCard(
      title: 'Request Parallelism',
      icon: Icons.multiple_stop_rounded,
      description: 'Control how many source operations may run at once',
      searchQuery: searchQuery,
      searchTerms: const [
        'AnimeHeaven concurrent parallel requests',
        'AnimePahe concurrent parallel requests',
        'Kwik concurrent temporary browser link resolution',
        'Nyaa concurrent parallel searches',
        'TokyoInsider concurrent parallel requests',
      ],
      children: [
        _ConcurrencyTile(
          iconAsset: AnimeSource.animeheaven.iconAsset,
          title: 'AnimeHeaven',
          subtitle: 'Download-link lookups and file checks',
          value: sources.animeHeavenRequestConcurrency,
          recommendedMaximum:
              SourcePreferences.recommendedAnimeHeavenRequestConcurrency,
          searchQuery: searchQuery,
          onSubmitted: notifier.setAnimeHeavenRequestConcurrency,
        ),
        _ConcurrencyTile(
          iconAsset: AnimeSource.animepahe.iconAsset,
          title: 'AnimePahe',
          subtitle: 'Episode pages, link lookups, and file checks',
          value: sources.animePaheRequestConcurrency,
          recommendedMaximum: SourcePreferences.recommendedRequestConcurrency,
          searchQuery: searchQuery,
          onSubmitted: notifier.setAnimePaheRequestConcurrency,
        ),
        _ConcurrencyTile(
          iconAsset: 'assets/images/kwik-icon.png',
          title: 'Kwik resolution',
          subtitle: 'AnimePahe download forms using temporary browser sessions',
          value: sources.kwikRequestConcurrency,
          recommendedMaximum:
              SourcePreferences.recommendedKwikRequestConcurrency,
          warnsAboutMemory: true,
          searchQuery: searchQuery,
          onSubmitted: notifier.setKwikRequestConcurrency,
        ),
        _ConcurrencyTile(
          iconAsset: AnimeSource.nyaa.iconAsset,
          title: 'Nyaa',
          subtitle: 'Native torrent search requests',
          value: sources.nyaaRequestConcurrency,
          recommendedMaximum:
              SourcePreferences.recommendedNyaaRequestConcurrency,
          searchQuery: searchQuery,
          onSubmitted: notifier.setNyaaRequestConcurrency,
        ),
        _ConcurrencyTile(
          iconAsset: AnimeSource.tokyoinsider.iconAsset,
          title: 'TokyoInsider',
          subtitle: 'Episode-page fetches and file checks',
          value: sources.tokyoInsiderRequestConcurrency,
          recommendedMaximum: SourcePreferences.recommendedRequestConcurrency,
          searchQuery: searchQuery,
          onSubmitted: notifier.setTokyoInsiderRequestConcurrency,
        ),
      ],
    );
  }
}

class _ConcurrencyTile extends StatelessWidget {
  final String iconAsset;
  final String title;
  final String subtitle;
  final int value;
  final int recommendedMaximum;
  final bool warnsAboutMemory;
  final String? searchQuery;
  final Future<void> Function(int value) onSubmitted;

  const _ConcurrencyTile({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.recommendedMaximum,
    this.warnsAboutMemory = false,
    required this.searchQuery,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final exceedsRecommendation = value > recommendedMaximum;
    return SettingsTile(
      leadingWidget: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          iconAsset,
          width: 20,
          height: 20,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.public, size: 20),
        ),
      ),
      title: title,
      titleSuffix: exceedsRecommendation
          ? Tooltip(
              message: warnsAboutMemory
                  ? 'This may trigger rate limits or blocking and use significantly more memory.'
                  : 'This may trigger rate limits or temporary source blocking.',
              child: Icon(
                Icons.warning_amber_rounded,
                size: 17,
                color: Theme.of(context).colorScheme.error,
              ),
            )
          : null,
      subtitle: exceedsRecommendation
          ? warnsAboutMemory
                ? '$subtitle. More than $recommendedMaximum workers may trigger rate limits or blocking and increase memory usage.'
                : '$subtitle. High parallelism may trigger rate limits or temporary blocking.'
          : subtitle,
      keywords: '$title concurrency parallel simultaneous requests workers',
      searchQuery: searchQuery,
      trailing: NumberSettingField(
        value: value,
        min: SourcePreferences.minRequestConcurrency,
        unit: 'at once',
        onSubmitted: (next) => unawaited(onSubmitted(next)),
      ),
    );
  }
}
