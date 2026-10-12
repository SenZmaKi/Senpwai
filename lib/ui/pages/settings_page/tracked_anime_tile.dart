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
    final title = tracked.animeSnapshot.title.display;
    final enabledSources = ref.watch(
      AppSettingsNotifier.provider.select(
        (settings) => settings.sources.enabledSources,
      ),
    );
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 52,
        height: 74,
        child: AnimeCoverImage(
          imageUrl: tracked.animeSnapshot.coverImage?.best,
          placeholderColor: theme.colorScheme.surfaceContainerHighest,
        ),
      ),
    );
    final drag = showDragHandle
        ? ReorderableDragStartListener(
            index: index,
            child: const MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.drag_indicator_rounded, size: 20),
              ),
            ),
          )
        : const SizedBox.shrink();
    final remove = IconButton(
      icon: const Icon(
        Icons.delete_outline_rounded,
        size: 20,
        semanticLabel: 'Remove tracking',
      ),
      onPressed: () => unawaited(_confirmAndUntrack(context, title)),
    );
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
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 600;
              Widget titleText() => Text(
                title,
                maxLines: compact ? 3 : 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              );
              Widget controls(double width) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TrackedSourceControl(
                    tracked: tracked,
                    enabledSources: enabledSources,
                    sourceWidth: compact ? width : 180,
                    trailing: [
                      SizedBox(
                        width: compact ? (width - 8) / 2 : 112,
                        child: Semantics(
                          label: 'Tracking resolution',
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
                        width: compact ? (width - 8) / 2 : 140,
                        child: Semantics(
                          label: 'Tracking language',
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
                  const SizedBox(height: 8),
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
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        cover,
                        const SizedBox(width: 12),
                        Expanded(child: titleText()),
                        drag,
                        remove,
                      ],
                    ),
                    const SizedBox(height: 12),
                    controls(constraints.maxWidth),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 24), child: drag),
                  cover,
                  const SizedBox(width: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, body) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          titleText(),
                          const SizedBox(height: 6),
                          controls(body.maxWidth),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  remove,
                ],
              );
            },
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
