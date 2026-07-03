import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/tracking/models.dart';
import 'package:senpwai/tracking/notifier.dart';
import 'package:senpwai/ui/components/anime_cover_image.dart';
import 'package:senpwai/ui/components/confirm_dialog.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';

class TrackingSettingsSection extends ConsumerWidget {
  const TrackingSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(TrackingNotifier.provider);
    final notifier = ref.read(TrackingNotifier.provider.notifier);
    if (tracking.trackedAnime.isEmpty) {
      return const SettingsTile(
        icon: Icons.playlist_remove_rounded,
        title: 'No tracked anime',
        subtitle: 'Use Track on an anime page to watch for future episodes',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsTile(
          icon: Icons.radar_rounded,
          title: 'Tracker Status',
          subtitle: tracking.checkInProgress
              ? 'Checking tracked anime now'
              : _lastCheckedSubtitle(tracking.lastCheckCompletedAt),
          trailing: _IconActionButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Check now',
            onPressed: tracking.checkInProgress
                ? null
                : () => unawaited(notifier.checkNow()),
          ),
        ),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: tracking.trackedAnime.length,
          onReorder: (oldIndex, newIndex) =>
              unawaited(notifier.reorder(oldIndex, newIndex)),
          itemBuilder: (context, index) {
            final tracked = tracking.trackedAnime[index];
            return _TrackedAnimeTile(
              key: ValueKey(tracked.anilistId),
              tracked: tracked,
              index: index,
              notifier: notifier,
            );
          },
        ),
      ],
    );
  }
}

class _TrackedAnimeTile extends StatelessWidget {
  final TrackedAnime tracked;
  final int index;
  final TrackingNotifier notifier;

  const _TrackedAnimeTile({
    super.key,
    required this.tracked,
    required this.index,
    required this.notifier,
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
              ReorderableDragStartListener(
                index: index,
                child: const MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: EdgeInsets.only(top: 24, right: 8),
                    child: Icon(Icons.drag_indicator_rounded, size: 20),
                  ),
                ),
              ),
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

String _lastCheckedSubtitle(DateTime? value) {
  if (value == null) return 'Waiting for the first automatic check';
  final elapsed = DateTime.now().difference(value);
  if (elapsed.inMinutes < 1) return 'Checked just now';
  if (elapsed.inHours < 1) return 'Checked ${elapsed.inMinutes} min ago';
  if (elapsed.inDays < 1) return 'Checked ${elapsed.inHours} hr ago';
  return 'Checked ${elapsed.inDays} days ago';
}
