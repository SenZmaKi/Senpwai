import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/pages/anime_page/anime_page_notifier.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_plan_review_dialog.dart';
import 'package:senpwai/ui/pages/anime_page/download_widgets.dart';
import 'package:senpwai/ui/shared/responsive.dart';
import 'package:senpwai/sources/shared/shared.dart';

/// Source picker + episode inputs + resolution/audio/folder/tracking + download button.
class AnimeDownloadSection extends ConsumerStatefulWidget {
  final AnimePageNotifier notifier;
  final AnimePageState pageState;

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
      text: widget.pageState.endEpisode.toString(),
    );
  }

  @override
  void didUpdateWidget(covariant AnimeDownloadSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controllers when state changes externally
    final newStart = widget.pageState.startEpisode.toString();
    final newEnd = widget.pageState.endEpisode.toString();
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

    final downloadControls = _buildDownloadControls(context, theme, state, notifier, mobile);

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
                      onChanged: notifier.setTrackingEnabled,
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
    AnimePageState state,
    AnimePageNotifier notifier,
    bool mobile,
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

    final downloadButton = MouseRegion(
      cursor: state.selectedSource != null && !state.isSubmittingDownload
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: ElevatedButton.icon(
        onPressed: state.selectedSource != null && !state.isSubmittingDownload
            ? () => unawaited(_handleDownload(context))
            : null,
        icon: state.isSubmittingDownload
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_rounded, size: 20),
        label: Text(
          state.isSubmittingDownload
              ? 'Preparing...'
              : state.selectedSource != null
              ? 'Download'
              : 'No source available',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: state.selectedSource != null
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: state.selectedSource != null
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface.withValues(alpha: 0.3),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: state.selectedSource != null ? 2 : 0,
        ),
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
            hintText: state.totalEpisodes.toString(),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
            isDense: true,
          ),
          onChanged: (v) {
            final val = int.tryParse(v);
            if (val != null) notifier.setEndEpisode(val);
          },
        ),
      ),
      const SizedBox(width: 8),
      Text(
        'of ${state.totalEpisodes}',
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
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Episodes label ───────────────────────────────────────────────
              DownloadSectionLabel(label: 'Episodes', icon: Icons.format_list_numbered_rounded),
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

  Future<void> _pickFolder(BuildContext context) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose download folder',
    );
    if (result != null) {
      widget.notifier.setDownloadFolder(result);
    }
  }

  Future<void> _handleDownload(BuildContext context) async {
    final state = widget.pageState;
    final notifier = widget.notifier;
    final totalEps = state.totalEpisodes;
    final startText = _startController.text.trim();
    final endText = _endController.text.trim();

    // Parse
    final start = startText.isEmpty ? 1 : int.tryParse(startText);
    final end = endText.isEmpty ? totalEps : int.tryParse(endText);

    if (start == null || end == null) {
      AppToast.showError(context, title: 'Enter valid episode numbers');
      return;
    }

    if (start == 0 || end == 0) {
      AppToast.showError(
        context,
        title: 'What am I supposed to do with a zero?',
      );
      return;
    }

    if (start < 0 || end < 0) {
      AppToast.showError(context, title: 'Episode numbers must be positive');
      return;
    }

    if (totalEps > 0 && start > totalEps) {
      AppToast.showError(
        context,
        title:
            'Start episode cannot be greater than the number of episodes the anime has',
      );
      _startController.text = '1';
      notifier.setStartEpisode(1);
      return;
    }

    if (end < start) {
      AppToast.showError(
        context,
        title: 'Stop episode cannot be less than start episode, hontoni baka ga',
      );
      _endController.text = totalEps.toString();
      notifier.setEndEpisode(totalEps);
      return;
    }

    if (totalEps > 0 && end > totalEps) {
      AppToast.showError(
        context,
        title:
            'Stop episode cannot be greater than the number of episodes this anime has',
      );
      _endController.text = totalEps.toString();
      notifier.setEndEpisode(totalEps);
      return;
    }

    notifier.setStartEpisode(start);
    notifier.setEndEpisode(end);
    try {
      final preparedBatch = await notifier.prepareDownloads();
      if (!context.mounted) return;
      if (state.selectedSource == AnimeSource.nyaa) {
        final confirmed = await NyaaPlanReviewDialog.confirm(
          context,
          batch: preparedBatch,
        );
        if (!confirmed) return;
      }
      final result = await notifier.enqueuePreparedDownloads(preparedBatch);
      if (!context.mounted) return;
      AppToast.showInfo(
        context,
        title: result.queuedCount == 1
            ? 'Download queued'
            : '${result.queuedCount} downloads queued',
        description: 'Episodes $start–$end from ${state.selectedSource!.label}',
      );
      for (final notice in result.notices) {
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
    } on DownloadUserError catch (error) {
      if (!context.mounted) return;
      AppToast.showError(
        context,
        title: error.title,
        description: error.description,
        copyPayload: error.copyPayload,
      );
    } catch (error, stackTrace) {
      if (!context.mounted) return;
      AppToast.showError(
        context,
        title: 'Failed to queue download',
        description: error.toString(),
        copyPayload: formatErrorForCopy(error, stackTrace),
      );
    }
  }
}

// ── Quick info sidebar (removed) ──────────────────────────────────────────────
