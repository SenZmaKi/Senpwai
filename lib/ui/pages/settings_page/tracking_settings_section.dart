import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/tracking/models.dart';
import 'package:senpwai/tracking/notifier.dart';
import 'package:senpwai/ui/pages/settings_page/anilist_account_card.dart';
import 'package:senpwai/ui/pages/settings_page/tracked_anime_tile.dart';
import 'package:senpwai/ui/pages/settings_page/settings_search.dart';
import 'package:senpwai/ui/pages/settings_page/settings_controls.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';

class TrackingSettingsSection extends ConsumerWidget {
  final AppSettings? settings;
  final AppSettingsNotifier? notifier;
  final String? searchQuery;

  const TrackingSettingsSection({
    super.key,
    this.settings,
    this.notifier,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(TrackingNotifier.provider);
    final trackingNotifier = ref.read(TrackingNotifier.provider.notifier);
    final generalTrackingMatch = settingsSearchMatches(searchQuery, const [
      'Tracking AniList',
      'Tracked Anime Auto-Downloader',
      'Monitors releases and automatically downloads new episodes',
      'Check interval',
      'Check on launch then repeat while Senpwai is running',
      'Disabled',
      'hours',
      'No tracked anime',
    ]);
    final trackerCheckIntervalHours =
        settings?.anilist.trackerCheckIntervalHours ??
        AnilistPreferences.defaultTrackerCheckIntervalHours;
    final trackerDisabled = trackerCheckIntervalHours == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnilistAccountCard(searchQuery: searchQuery),
        SettingsGroupCard(
          title: 'Tracked Anime Auto-Downloader',
          icon: Icons.radar_rounded,
          description: trackerDisabled
              ? 'Tracking disabled · saved preferences can still be edited'
              : tracking.checkInProgress
              ? 'Checking tracked anime for new episodes...'
              : 'Monitors releases and automatically downloads new episodes',
          searchQuery: searchQuery,
          headerTrailing: _IconActionButton(
            icon: Icons.refresh_rounded,
            tooltip: tracking.checkInProgress ? 'Checking...' : 'Check now',
            loading: tracking.checkInProgress,
            onPressed: tracking.checkInProgress || trackerDisabled
                ? null
                : () => unawaited(trackingNotifier.checkNow()),
          ),
          children: [
            if (settings != null && notifier != null)
              SettingsTile(
                icon: Icons.schedule_rounded,
                title: 'Check interval',
                subtitle: trackerDisabled
                    ? 'Disabled'
                    : 'Check on launch, then repeat while Senpwai is running',
                searchQuery: searchQuery,
                trailing: LimitSettingControl(
                  mode: trackerDisabled
                      ? LimitMode.disabled
                      : LimitMode.limited,
                  allowsUnlimited: false,
                  onModeChanged: (mode) => unawaited(
                    notifier!.setTrackerCheckIntervalHours(
                      mode == LimitMode.disabled
                          ? 0
                          : _trackerIntervalForCustomValue(
                              settings!.anilist.trackerCheckIntervalHours,
                            ),
                    ),
                  ),
                  valueField: NumberSettingField(
                    value: _trackerIntervalForCustomValue(
                      settings!.anilist.trackerCheckIntervalHours,
                    ),
                    min: 1,
                    unit: 'hours',
                    zeroValueModeShortcut: true,
                    onSubmitted: (hours) => unawaited(
                      notifier!.setTrackerCheckIntervalHours(hours),
                    ),
                  ),
                ),
              ),
            _TrackedAnimeList(
              trackedAnime: tracking.trackedAnime,
              notifier: trackingNotifier,
              searchQuery: searchQuery,
              generalTrackingMatch: generalTrackingMatch,
              enabled: !trackerDisabled,
            ),
          ],
        ),
      ],
    );
  }
}

int _trackerIntervalForCustomValue(int hours) =>
    hours > 0 ? hours : AnilistPreferences.defaultTrackerCheckIntervalHours;

class _TrackedAnimeList extends StatelessWidget implements SettingsSearchable {
  final List<TrackedAnime> trackedAnime;
  final TrackingNotifier notifier;
  final String? searchQuery;
  final bool generalTrackingMatch;
  final bool enabled;

  const _TrackedAnimeList({
    required this.trackedAnime,
    required this.notifier,
    required this.searchQuery,
    required this.generalTrackingMatch,
    required this.enabled,
  });

  @override
  bool matchesSearch(String? query) {
    if (trackedAnime.isEmpty) {
      return settingsSearchMatches(query, const [
        'No tracked anime',
        'Use Track on an anime page to watch for future episodes',
      ]);
    }
    return generalTrackingMatch ||
        trackedAnime.any((tracked) => _matchesTrackedAnime(tracked, query));
  }

  @override
  Widget build(BuildContext context) =>
      Opacity(opacity: enabled ? 1 : 0.45, child: _buildList(context));

  Widget _buildList(BuildContext context) {
    final isSearching = searchQuery?.trim().isNotEmpty ?? false;
    if (trackedAnime.isEmpty) {
      return const SettingsTile(
        icon: Icons.playlist_remove_rounded,
        title: 'No tracked anime',
        subtitle: 'Use Track on an anime page to watch for future episodes',
      );
    }

    if (isSearching) {
      final matchingTrackedAnime = trackedAnime.indexed
          .where(
            (entry) =>
                generalTrackingMatch ||
                _matchesTrackedAnime(entry.$2, searchQuery),
          )
          .toList();
      return Column(
        children: [
          for (final entry in matchingTrackedAnime)
            TrackedAnimeTile(
              key: ValueKey(entry.$2.anilistId),
              tracked: entry.$2,
              index: entry.$1,
              notifier: notifier,
              showDragHandle: false,
            ),
        ],
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: trackedAnime.length,
      onReorderItem: (oldIndex, newIndex) =>
          unawaited(notifier.reorder(oldIndex, newIndex)),
      itemBuilder: (context, index) {
        final tracked = trackedAnime[index];
        return TrackedAnimeTile(
          key: ValueKey(tracked.anilistId),
          tracked: tracked,
          index: index,
          notifier: notifier,
        );
      },
    );
  }
}

bool _matchesTrackedAnime(TrackedAnime tracked, String? query) =>
    settingsSearchMatches(query, [
      tracked.animeSnapshot.title.display,
      tracked.downloadFolder,
      tracked.resolution.toString(),
      tracked.language.toString(),
      trackedSourceLabel(tracked),
      if (tracked.lastError != null) tracked.lastError!,
    ]);

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool loading;

  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 20),
      ),
    );
  }
}
