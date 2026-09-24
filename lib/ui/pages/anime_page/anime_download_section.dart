import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/downloads/anime_download_session.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/ui/components/app.dart';
import 'package:senpwai/ui/components/confirm_dialog.dart';
import 'package:senpwai/ui/components/pulsing_progress_bar.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_review/nyaa_review_sheet.dart';
import 'package:senpwai/ui/pages/anime_page/download_widgets.dart';
import 'package:senpwai/ui/shared/responsive.dart';
import 'package:senpwai/sources/shared/shared.dart';

/// Source picker + episode inputs + resolution/audio/folder/tracking + download button.
class AnimeDownloadSection extends ConsumerStatefulWidget {
  final AnimeDownloadSessionNotifier notifier;
  final AnimeDownloadSessionState pageState;

  const AnimeDownloadSection({
    super.key,
    required this.notifier,
    required this.pageState,
  });

  @override
  ConsumerState<AnimeDownloadSection> createState() =>
      _AnimeDownloadSectionState();
}

class _AnimeDownloadSectionState extends ConsumerState<AnimeDownloadSection> {
  late final TextEditingController _startController;
  late final TextEditingController _endController;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(
      text: widget.pageState.startEpisode.toString(),
    );
    _endController = TextEditingController(
      text: widget.pageState.endEpisodeUsesLatest
          ? ''
          : widget.pageState.endEpisode.toString(),
    );
  }

  @override
  void didUpdateWidget(covariant AnimeDownloadSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controllers when state changes externally
    final newStart = widget.pageState.startEpisode.toString();
    final newEnd = widget.pageState.endEpisodeUsesLatest
        ? ''
        : widget.pageState.endEpisode.toString();
    if (_startController.text != newStart) _startController.text = newStart;
    if (_endController.text != newEnd) _endController.text = newEnd;
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = horizontalPadding(context);
    final state = widget.pageState;
    final notifier = widget.notifier;
    final mobile = isMobile(context);
    final canStartDownload =
        state.selectedSource != null &&
        state.hasAvailableEpisodes &&
        !state.isSubmittingDownload;

    final downloadControls = _buildDownloadControls(
      context,
      theme,
      state,
      notifier,
      mobile,
      canStartDownload,
    );

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(pad, 12, pad, 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Download',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),

                // Source dropdown + Track switch in one row
                Row(
                  children: [
                    Expanded(
                      child: SourceDropdown(state: state, notifier: notifier),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Track',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Switch(
                      value: state.trackingEnabled,
                      onChanged: (enabled) =>
                          unawaited(_setTrackingEnabled(context, enabled)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                SizedBox(height: 8),

                downloadControls,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadControls(
    BuildContext context,
    ThemeData theme,
    AnimeDownloadSessionState state,
    AnimeDownloadSessionNotifier notifier,
    bool mobile,
    bool canStartDownload,
  ) {
    final folderPicker = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _pickFolder(context),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.25),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.downloadFolder ?? 'Choose folder',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: state.downloadFolder != null
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );

    final canCancelPlanning =
        state.submissionStage == DownloadSubmissionStage.planning &&
        !state.planningCancellationRequested;
    final canPressDownloadButton = canStartDownload || canCancelPlanning;
    final isPlanning =
        state.submissionStage == DownloadSubmissionStage.planning;
    final downloadButton = MouseRegion(
      cursor: canPressDownloadButton
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: Stack(
        children: [
          ElevatedButton.icon(
            onPressed: canCancelPlanning
                ? () => unawaited(_confirmCancelPlanning())
                : canStartDownload
                ? () => unawaited(_handleDownload(context))
                : null,
            icon: isPlanning && !state.planningCancellationRequested
                ? const Icon(Icons.close_rounded, size: 20)
                : state.isSubmittingDownload
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, size: 20),
            label: Text(
              state.submitButtonLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: canPressDownloadButton
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              foregroundColor: canPressDownloadButton
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: canStartDownload ? 2 : 0,
            ),
          ),
          if (isPlanning && !state.planningCancellationRequested)
            Positioned(
              left: 10,
              right: 10,
              bottom: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: PulsingProgressBar(
                  height: 3,
                  value:
                      state.planningProgress == null ||
                              state.planningProgress!.completedEpisodes == 0
                          ? null
                          : state.planningProgress!.fraction,
                  color: theme.colorScheme.onPrimary,
                  trackColor: theme.colorScheme.onPrimary.withValues(
                    alpha: 0.22,
                  ),
                  pulseColor:
                      ThemeData.estimateBrightnessForColor(
                            theme.colorScheme.onPrimary,
                          ) ==
                          Brightness.light
                          ? const Color(0x66FFFFFF)
                          : const Color(0x44FFFFFF),
                  segments: (state.planningProgress?.totalEpisodes ?? 0) > 1
                      ? state.planningProgress!.totalEpisodes
                      : null,
                  tickColor: theme.colorScheme.primary,
                  semanticsLabel: state.planningProgress?.activity,
                  semanticsValue: state.planningProgress == null
                      ? null
                      : '${(state.planningProgress!.fraction * 100).round()}%',
                ),
              ),
            ),
        ],
      ),
    );

    // Episode range fields (reused in both layouts)
    final rangeFields = [
      SizedBox(
        width: 80,
        child: TextField(
          controller: _startController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '1',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
            isDense: true,
          ),
          onChanged: (v) {
            final val = int.tryParse(v);
            if (val != null) notifier.setStartEpisode(val);
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          '–',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
      SizedBox(
        width: 80,
        child: TextField(
          controller: _endController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: state.availableEpisodes.toString(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
            isDense: true,
          ),
          onChanged: (v) {
            if (v.trim().isEmpty) {
              notifier.useLatestEndEpisode();
              return;
            }
            final val = int.tryParse(v);
            if (val != null) notifier.setEndEpisode(val);
          },
        ),
      ),
      const SizedBox(width: 8),
      Text(
        'of ${state.availableEpisodes}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Controls card ─────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Episodes label ───────────────────────────────────────────────
              DownloadSectionLabel(
                label: 'Episodes',
                icon: Icons.format_list_numbered_rounded,
              ),
              SizedBox(height: 6),
              // Episode range fields
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: rangeFields,
              ),

              SizedBox(height: 10),

              // ── Quality + Audio ──────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: DownloadDropdown<Resolution>(
                      label: 'Quality',
                      icon: Icons.hd_outlined,
                      options: const [
                        Resolution.res1080p,
                        Resolution.res720p,
                        Resolution.res480p,
                        Resolution.res360p,
                      ],
                      selected: state.selectedResolution,
                      labelBuilder: (r) => r.toString(),
                      onSelected: notifier.setResolution,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DownloadDropdown<Language>(
                      label: 'Audio',
                      icon: Icons.headphones_rounded,
                      options: Language.values,
                      selected: state.selectedLanguage,
                      labelBuilder: (l) => l.toString(),
                      onSelected: notifier.setLanguage,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Bottom: folder + download ─────────────────────────────────────────
        if (mobile) ...[
          SizedBox(width: double.infinity, child: folderPicker),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: downloadButton),
        ] else ...[
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(flex: 40, child: folderPicker),
                const SizedBox(width: 10),
                Expanded(flex: 60, child: downloadButton),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmCancelPlanning() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel download planning?',
      message:
          'The work completed so far will be discarded and no downloads will be added to the queue.',
      confirmLabel: 'Cancel planning',
      cancelLabel: 'Keep planning',
      destructive: true,
    );
    if (!mounted || !confirmed) return;

    final state = widget.notifier.currentState;
    if (state.submissionStage == DownloadSubmissionStage.planning &&
        !state.planningCancellationRequested) {
      widget.notifier.cancelDownloadPlanning();
    }
  }

  Future<void> _pickFolder(BuildContext context) async {
    final initialDirectory = await _folderPickerInitialDirectory(
      widget.pageState.downloadFolder,
    );
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose download folder',
      initialDirectory: initialDirectory,
    );
    if (result != null) {
      await widget.notifier.setDownloadFolder(result);
    }
  }

  Future<void> _setTrackingEnabled(BuildContext context, bool enabled) async {
    try {
      await widget.notifier.setTrackingEnabled(enabled);
    } on DownloadUserError catch (error) {
      if (!context.mounted) return;
      AppToast.showError(
        context,
        title: error.title,
        description: error.description,
        copyPayload: error.copyPayload,
      );
    } on Object catch (error, stackTrace) {
      if (!context.mounted) return;
      AppToast.showError(
        context,
        title: 'Tracking failed',
        description: error.toString(),
        copyPayload: formatErrorForCopy(error, stackTrace),
      );
    }
  }

  Future<void> _handleDownload(BuildContext context) async {
    final notifier = widget.notifier;
    final navigator = Navigator.of(context);
    try {
      notifier.startDownloadPlanning();
      final preparedBatch = await notifier.prepareDownloads(
        startInput: _startController.text,
        endInput: _endController.text,
      );
      PreparedDownloadBatch reviewedBatch = preparedBatch;
      if (!context.mounted) {
        return;
      }
      final isNyaa =
          preparedBatch.jobs.any((j) => j.source == AnimeSource.nyaa) ||
          preparedBatch.nyaaEpisodeIssues.isNotEmpty;
      final skipNyaaReview = ref
          .read(AppSettingsNotifier.provider)
          .sources
          .skipNyaaReviewWhenUnambiguous;
      if (isNyaa &&
          (!skipNyaaReview || preparedBatch.nyaaEpisodeIssues.isNotEmpty)) {
        notifier.setSubmissionStage(DownloadSubmissionStage.reviewing);
        final resolvedBatch = await NyaaReviewSheet.show(
          context,
          batch: preparedBatch,
          notifier: notifier,
        );
        if (!context.mounted) {
          return;
        }
        if (resolvedBatch == null) {
          notifier.resetSubmissionStage();
          return;
        }
        reviewedBatch = resolvedBatch;
      }
      if (reviewedBatch.unavailableEpisodeNumbers.isNotEmpty) {
        notifier.setSubmissionStage(DownloadSubmissionStage.reviewing);
        final unavailable = reviewedBatch.unavailableEpisodeNumbers;
        final found = [
          for (final job in reviewedBatch.jobs)
            if (job is PreparedHttpDownloadJob && job.episodeNumber != null)
              job.episodeNumber!,
        ]..sort();
        final shouldDownload = await showConfirmDialog(
          context,
          title: 'Some episodes were not found',
          content: Text.rich(
            TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text:
                      'Not found: ${_episodeListLabel(unavailable)}.\n\nFound: ',
                ),
                TextSpan(
                  text: _episodeListLabel(found),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '. Download the found episodes?'),
              ],
            ),
          ),
          confirmLabel: 'Download found',
          cancelLabel: 'Cancel',
        );
        if (!context.mounted) return;
        if (!shouldDownload) {
          notifier.resetSubmissionStage();
          return;
        }
      }
      if (reviewedBatch.jobs.isEmpty) {
        notifier.resetSubmissionStage();
        AppToast.showInfo(
          context,
          title: 'No downloads queued',
          description: 'All unavailable episodes were skipped.',
        );
        return;
      }
      notifier.setSubmissionStage(DownloadSubmissionStage.queueing);
      final result = await notifier.enqueuePreparedDownloads(reviewedBatch);
      if (!context.mounted) return;
      notifier.resetSubmissionStage();
      ref.read(AppPageNotifier.provider.notifier).showDownloads();
      if (navigator.mounted) {
        navigator.pop();
      }
      _showDownloadNotices(result.notices);
    } on DownloadPlanningCancelled {
      if (!context.mounted) return;
      notifier.resetSubmissionStage();
    } on DownloadUserError catch (error) {
      if (!context.mounted) return;
      notifier.resetSubmissionStage();
      AppToast.showError(
        context,
        title: error.title,
        description: error.description,
        copyPayload: error.copyPayload,
      );
    } catch (error, stackTrace) {
      if (!context.mounted) return;
      notifier.resetSubmissionStage();
      AppToast.showError(
        context,
        title: 'Failed to queue download',
        description: error.toString(),
        copyPayload: formatErrorForCopy(error, stackTrace),
      );
    }
  }

  void _showDownloadNotices(Iterable<DownloadNotice> notices) {
    final context = App.navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    for (final notice in notices) {
      switch (notice.level) {
        case DownloadNoticeLevel.info:
          AppToast.showInfo(
            context,
            title: notice.title,
            description: notice.description,
          );
        case DownloadNoticeLevel.warning:
          AppToast.showWarning(
            context,
            title: notice.title,
            description: notice.description,
          );
      }
    }
  }
}

String _episodeListLabel(List<int> episodes) {
  final ranges = <String>[];
  var rangeStart = episodes.first;
  var rangeEnd = rangeStart;
  for (final episode in episodes.skip(1)) {
    if (episode == rangeEnd + 1) {
      rangeEnd = episode;
      continue;
    }
    ranges.add(
      rangeStart == rangeEnd ? '$rangeStart' : '$rangeStart–$rangeEnd',
    );
    rangeStart = rangeEnd = episode;
  }
  ranges.add(rangeStart == rangeEnd ? '$rangeStart' : '$rangeStart–$rangeEnd');
  return '${episodes.length == 1 ? 'episode' : 'episodes'} ${ranges.join(', ')}';
}

Future<String?> _folderPickerInitialDirectory(String? targetFolder) async {
  final folder = targetFolder?.trim();
  if (folder == null || folder.isEmpty) return null;
  var directory = Directory(folder);
  while (!await directory.exists()) {
    final parent = path.dirname(directory.path);
    if (parent == directory.path) return null;
    directory = Directory(parent);
  }
  return directory.path;
}

// ── Quick info sidebar (removed) ──────────────────────────────────────────────
