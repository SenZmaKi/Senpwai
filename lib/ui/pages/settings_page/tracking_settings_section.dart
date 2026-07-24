import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/tracking/models.dart';
import 'package:senpwai/tracking/notifier.dart';
import 'package:senpwai/ui/components/anime_cover_image.dart';
import 'package:senpwai/ui/components/confirm_dialog.dart';
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
    final isSearching = searchQuery?.trim().isNotEmpty ?? false;
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
    final matchingTrackedAnime = tracking.trackedAnime.indexed
        .where(
          (entry) =>
              generalTrackingMatch ||
              settingsSearchMatches(searchQuery, [
                entry.$2.animeSnapshot.title.display,
                entry.$2.downloadFolder,
                entry.$2.resolution.toString(),
                entry.$2.language.toString(),
                _sourceLabel(entry.$2),
                if (entry.$2.lastError != null) entry.$2.lastError!,
              ]),
        )
        .toList();
    final showTrackedAnime =
        !isSearching ||
        matchingTrackedAnime.isNotEmpty ||
        (tracking.trackedAnime.isEmpty && generalTrackingMatch);
    final trackerCheckIntervalHours =
        settings?.anilist.trackerCheckIntervalHours ??
        AnilistPreferences.defaultTrackerCheckIntervalHours;
    final trackerDisabled = trackerCheckIntervalHours == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (settings != null && notifier != null) ...[
          SettingsGroupCard(
            title: 'AniList Account & Sync',
            icon: Icons.sync_rounded,
            description:
                'Automatic watch status updates and profile synchronization',
            searchQuery: searchQuery,
            children: [
              SettingsTile(
                icon: Icons.sync_rounded,
                title: 'Sync Watching to Tracked Anime',
                subtitle: 'Automatically sync watched episodes with AniList',
                searchQuery: searchQuery,
                trailing: AsyncSwitch(
                  value: settings!.anilist.syncWatchingToTrackedAnime,
                  onChanged: notifier!.setSyncWatchingToTrackedAnime,
                ),
              ),
            ],
          ),
        ],
        SettingsGroupCard(
          title: 'Tracked Anime Auto-Downloader',
          icon: Icons.radar_rounded,
          description:
              'Monitors releases and automatically downloads new episodes',
          searchQuery: searchQuery,
          headerTrailing: _IconActionButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Check now',
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
                trailing: NumberSettingField(
                  value: settings!.anilist.trackerCheckIntervalHours,
                  min: 0,
                  unit: 'hours',
                  onSubmitted: (hours) =>
                      unawaited(notifier!.setTrackerCheckIntervalHours(hours)),
                ),
              ),
          ],
        ),
        if (showTrackedAnime) ...[
          const SizedBox(height: 16),
          if (tracking.trackedAnime.isEmpty)
            const SettingsGroupCard(
              children: [
                SettingsTile(
                  icon: Icons.playlist_remove_rounded,
                  title: 'No tracked anime',
                  subtitle:
                      'Use Track on an anime page to watch for future episodes',
                ),
              ],
            )
          else if (isSearching)
            Column(
              children: [
                for (final entry in matchingTrackedAnime)
                  _TrackedAnimeTile(
                    key: ValueKey(entry.$2.anilistId),
                    tracked: entry.$2,
                    index: entry.$1,
                    notifier: trackingNotifier,
                    showDragHandle: false,
                  ),
              ],
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: tracking.trackedAnime.length,
              onReorder: (oldIndex, newIndex) =>
                  unawaited(trackingNotifier.reorder(oldIndex, newIndex)),
              itemBuilder: (context, index) {
                final tracked = tracking.trackedAnime[index];
                return _TrackedAnimeTile(
                  key: ValueKey(tracked.anilistId),
                  tracked: tracked,
                  index: index,
                  notifier: trackingNotifier,
                );
              },
            ),
        ],
      ],
    );
  }
}

class _TrackedAnimeTile extends StatelessWidget {
  final TrackedAnime tracked;
  final int index;
  final TrackingNotifier notifier;
  final bool showDragHandle;

  const _TrackedAnimeTile({
    super.key,
    required this.tracked,
    required this.index,
    required this.notifier,
    this.showDragHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final anime = tracked.animeSnapshot;
    final title = anime.title.display;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.12),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showDragHandle)
                ReorderableDragStartListener(
                  index: index,
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: EdgeInsets.only(top: 24, right: 8),
                      child: Icon(Icons.drag_indicator_rounded, size: 20),
                    ),
                  ),
                )
              else
                const SizedBox(width: 28),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 52,
                  height: 74,
                  child: AnimeCoverImage(
                    imageUrl: anime.coverImage?.best,
                    placeholderColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MetaChip(_sourceLabel(tracked)),
                        _MetaChip(tracked.resolution.toString()),
                        _MetaChip(tracked.language.toString()),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tracked.downloadFolder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                    if (tracked.lastError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        tracked.lastError!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: _IconActionButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Remove tracking',
                  onPressed: () =>
                      unawaited(_confirmAndUntrack(context, title)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndUntrack(BuildContext context, String title) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove tracked anime?',
      message:
          'Stop tracking "$title" for new episodes. This will not delete downloaded files.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) return;
    await notifier.untrackAnime(tracked.anilistId);
  }
}

String _sourceLabel(TrackedAnime tracked) {
  final source = tracked.preferredSource;
  if (source == null) return 'Auto';
  if (tracked.sourceSelectedByUser) return source.label;
  return 'Auto: ${source.label}';
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip(this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
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
        icon: Icon(icon, size: 20),
      ),
    );
  }
}
