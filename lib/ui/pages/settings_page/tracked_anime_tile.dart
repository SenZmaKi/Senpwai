import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/ui/pages/anime_page/download_widgets.dart';
import 'package:senpwai/tracking/models.dart';
import 'package:senpwai/tracking/notifier.dart';
import 'package:senpwai/ui/components/anime_cover_image.dart';
import 'package:senpwai/ui/components/confirm_dialog.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/pages/settings_page/tracked_source_control.dart';
import 'package:senpwai/ui/pages/settings_page/tracked_folder_control.dart';

class TrackedAnimeTile extends ConsumerWidget {
  final TrackedAnime tracked;
  final int index;
  final TrackingNotifier notifier;
  final bool showDragHandle;

  const TrackedAnimeTile({
    super.key,
    required this.tracked,
    required this.index,
    required this.notifier,
    this.showDragHandle = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    TrackedSourceControl(
                      tracked: tracked,
                      enabledSources: ref.watch(
                        AppSettingsNotifier.provider.select(
                          (settings) => settings.sources.enabledSources,
                        ),
                      ),
                      trailing: [
                        SizedBox(
                          width: 112,
                          child: Tooltip(
                            message: 'Tracking resolution',
                            child: DownloadDropdown<Resolution>(
                              label: 'Resolution',
                              showLabel: false,
                              options: downloadResolutionOptions,
                              selected: tracked.resolution,
                              labelBuilder: (value) => value.toString(),
                              onSelected: (value) => unawaited(
                                _savePreferences(context, resolution: value),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: Tooltip(
                            message: 'Tracking language',
                            child: DownloadDropdown<Language>(
                              label: 'Language',
                              showLabel: false,
                              options: Language.values,
                              selected: tracked.language,
                              labelBuilder: (value) => value.toString(),
                              onSelected: (value) => unawaited(
                                _savePreferences(context, language: value),
                              ),
                            ),
                          ),
                        ),
                      ],
                      checkSource: (source) =>
                          notifier.checkSource(tracked.anilistId, source),
                      onChanged: (source) =>
                          notifier.updateSource(tracked.anilistId, source),
                    ),
                    const SizedBox(height: 6),
                    TrackedFolderControl(
                      folder: tracked.downloadFolder,
                      onChanged: (folder) => ref
                          .read(AppSettingsNotifier.provider.notifier)
                          .upsertCustomAnimeFolder(
                            animeTitle: title,
                            folder: folder,
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
                child: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
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

  Future<void> _savePreferences(
    BuildContext context, {
    Resolution? resolution,
    Language? language,
  }) async {
    try {
      await notifier.updatePreferences(
        tracked.anilistId,
        resolution: resolution,
        language: language,
      );
    } catch (_) {
      if (context.mounted) {
        AppToast.showError(
          context,
          title: 'Couldn’t save preferences',
          description: 'Your previous settings are still active. Try again.',
        );
      }
    }
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

String trackedSourceLabel(TrackedAnime tracked) {
  final source = tracked.preferredSource;
  if (source == null) return 'Auto';
  if (tracked.sourceSelectedByUser) return 'Locked: ${source.label}';
  return 'Auto: ${source.label}';
}
