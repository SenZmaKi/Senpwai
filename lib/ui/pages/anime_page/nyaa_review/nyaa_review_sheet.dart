import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/anime_download_session.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_plan_components.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_review/countdown_start_button.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_review/episode_review_row.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_review/torrent_meta_row.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_review/torrent_picker_view.dart';

const _autoStartDuration = Duration(seconds: 4);

class NyaaReviewSheet extends ConsumerStatefulWidget {
  final PreparedDownloadBatch batch;
  final AnimeDownloadSessionNotifier notifier;

  const NyaaReviewSheet({
    super.key,
    required this.batch,
    required this.notifier,
  });

  static Future<PreparedDownloadBatch?> show(
    BuildContext context, {
    required PreparedDownloadBatch batch,
    required AnimeDownloadSessionNotifier notifier,
  }) {
    return showModalBottomSheet<PreparedDownloadBatch>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NyaaReviewSheet(batch: batch, notifier: notifier),
    );
  }

  @override
  ConsumerState<NyaaReviewSheet> createState() => _NyaaReviewSheetState();
}

class _NyaaReviewSheetState extends ConsumerState<NyaaReviewSheet>
    with SingleTickerProviderStateMixin {
  /// Episode overrides applied by the user via the picker. Wins over the
  /// auto-planned job for that episode number.
  final Map<int, PreparedTorrentDownloadJob> _episodeOverrides = {};
  final Set<int> _skippedEpisodes = {};

  /// Shared filter state across all picker invocations within this sheet.
  late NyaaManualSearchFilters _filters;

  late final AnimationController _countdown;
  bool _countdownActive = false;
  bool _countdownConsumed = false;

  final _draggableController = DraggableScrollableController();

  late final _sheetNavKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    final sourceSettings = ref.read(AppSettingsNotifier.provider).sources;
    _filters = sourceSettings.nyaaDefaultFilters;
    if (sourceSettings.skipUnavailableNyaaEpisodes) {
      _skippedEpisodes.addAll(
        widget.batch.nyaaEpisodeIssues.map((issue) => issue.episodeNumber),
      );
    }
    _countdown = AnimationController(vsync: this, duration: _autoStartDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && _countdownActive) {
          _countdownActive = false;
          _countdownConsumed = true;
          _autoStart();
        }
      });
    _maybeStartCountdown();
  }

  @override
  void dispose() {
    _countdown.dispose();
    _draggableController.dispose();
    super.dispose();
  }

  bool get _hasUnresolved => _unresolvedIssues.isNotEmpty;

  List<NyaaEpisodeResolutionIssue> get _unresolvedIssues => widget
      .batch
      .nyaaEpisodeIssues
      .where(
        (i) =>
            !_episodeOverrides.containsKey(i.episodeNumber) &&
            !_skippedEpisodes.contains(i.episodeNumber),
      )
      .toList();

  void _skipEpisode(int episodeNumber) {
    _cancelCountdown();
    setState(() {
      _episodeOverrides.remove(episodeNumber);
      _skippedEpisodes.add(episodeNumber);
    });
  }

  void _undoSkip(int episodeNumber) {
    _cancelCountdown();
    setState(() => _skippedEpisodes.remove(episodeNumber));
  }

  /// Final batch built from initial auto-planned jobs + overrides + any
  /// resolved issues.
  PreparedDownloadBatch _buildResolvedBatch() {
    final jobs = <PreparedDownloadJob>[];
    for (final job in widget.batch.jobs) {
      if (job is PreparedTorrentDownloadJob) {
        final trimmedBatch = _trimBatchJobOverrides(job);
        if (trimmedBatch == null) continue;
        if (!identical(trimmedBatch, job)) {
          jobs.add(trimmedBatch);
          continue;
        }
        final ep = job.reviewMetadata?.episodeNumber;
        if (ep != null && _episodeOverrides.containsKey(ep)) {
          jobs.add(_episodeOverrides[ep]!);
          continue;
        }
      }
      jobs.add(job);
    }
    // Resolved issues — episodes that started as unresolved and now have an
    // override.
    for (final issue in widget.batch.nyaaEpisodeIssues) {
      final override = _episodeOverrides[issue.episodeNumber];
      if (override != null && !_alreadyInJobs(jobs, issue.episodeNumber)) {
        jobs.add(override);
      }
    }
    return widget.batch.copyWith(jobs: jobs, nyaaEpisodeIssues: const []);
  }

  bool _alreadyInJobs(List<PreparedDownloadJob> jobs, int episodeNumber) {
    return jobs.any(
      (j) =>
          j is PreparedTorrentDownloadJob &&
          j.reviewMetadata?.episodeNumber == episodeNumber,
    );
  }

  PreparedTorrentDownloadJob? _trimBatchJobOverrides(
    PreparedTorrentDownloadJob job,
  ) {
    final meta = job.reviewMetadata;
    if (meta == null || !meta.isBatch || meta.batchEpisodeNumbers.isEmpty) {
      return job;
    }
    final overriddenEpisodes = meta.batchEpisodeNumbers
        .where(_episodeOverrides.containsKey)
        .toSet();
    if (overriddenEpisodes.isEmpty) return job;

    final selectedFileIndices = <int>[];
    final selectedFilePaths = <String>[];
    final renamedFilePaths = <int, String>{};
    final remainingEpisodes = <int>[];
    final remainingFileSizes = <int, int>{};
    var totalBytes = 0;

    for (var i = 0; i < meta.batchEpisodeNumbers.length; i++) {
      final episodeNumber = meta.batchEpisodeNumbers[i];
      if (overriddenEpisodes.contains(episodeNumber)) continue;
      if (i >= job.selectedFileIndices.length ||
          i >= job.selectedFilePaths.length) {
        continue;
      }
      final fileIndex = job.selectedFileIndices[i];
      selectedFileIndices.add(fileIndex);
      selectedFilePaths.add(job.selectedFilePaths[i]);
      final renamedPath = job.renamedFilePaths[fileIndex];
      if (renamedPath != null) {
        renamedFilePaths[fileIndex] = renamedPath;
      }
      remainingEpisodes.add(episodeNumber);
      final fileSize = meta.batchEpisodeFileSizes[episodeNumber] ?? 0;
      remainingFileSizes[episodeNumber] = fileSize;
      totalBytes += fileSize;
    }

    if (remainingEpisodes.isEmpty) return null;
    return PreparedTorrentDownloadJob(
      source: job.source,
      animeTitle: job.animeTitle,
      displayTitle: job.displayTitle,
      destinationDirectory: job.destinationDirectory,
      totalBytes: totalBytes > 0 ? totalBytes : job.totalBytes,
      torrentData: job.torrentData,
      torrentName: job.torrentName,
      selectedFileIndices: selectedFileIndices,
      selectedFilePaths: selectedFilePaths,
      renamedFilePaths: renamedFilePaths,
      reviewMetadata: TorrentReviewMetadata(
        episodeNumber: meta.episodeNumber,
        resolution: meta.resolution,
        seeders: meta.seeders,
        languageLabel: meta.languageLabel,
        isBatch: meta.isBatch,
        searchConfiguration: meta.searchConfiguration,
        batchEpisodeNumbers: remainingEpisodes,
        batchEpisodeFileSizes: remainingFileSizes,
      ),
    );
  }

  void _maybeStartCountdown() {
    if (_countdownConsumed) return;
    if (_hasUnresolved) return;
    if (widget.batch.jobs.isEmpty) return;
    _countdownActive = true;
    _countdown.forward(from: 0);
  }

  void _cancelCountdown({bool expand = true}) {
    if (!_countdownActive) return;
    _countdownActive = false;
    _countdownConsumed = true;
    _countdown.stop();
    setState(() {});
    if (expand && _draggableController.isAttached) {
      _draggableController.animateTo(
        0.95,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _autoStart() {
    if (!mounted) return;
    Navigator.of(context).pop(_buildResolvedBatch());
  }

  void _start() {
    Navigator.of(context).pop(_buildResolvedBatch());
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  void _openPicker({
    required int episodeNumber,
    required String episodeTitle,
    required NyaaSearchConfiguration searchConfiguration,
    required String? currentTorrentFilename,
  }) {
    _cancelCountdown();
    _filters = searchConfiguration.filters;
    _sheetNavKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => TorrentPickerView(
          episodeNumber: episodeNumber,
          episodeTitle: episodeTitle,
          searchConfiguration: searchConfiguration,
          currentTorrentFilename: currentTorrentFilename,
          filters: _filters,
          onFiltersChanged: (f) => setState(() => _filters = f),
          onSearch: ({required query, required filters}) =>
              widget.notifier.searchNyaaManualCandidates(
                episodeNumber: episodeNumber,
                query: query,
                filters: filters,
              ),
          onPlanCandidate: (candidate) => widget.notifier.planManualNyaaEpisode(
            episodeNumber: episodeNumber,
            candidate: candidate,
          ),
          onResolved: (job) {
            setState(() {
              _skippedEpisodes.remove(episodeNumber);
              _episodeOverrides[episodeNumber] = job;
            });
            _sheetNavKey.currentState?.pop();
          },
          onClose: () => _sheetNavKey.currentState?.pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _cancelCountdown(),
      onPointerHover: (_) => _cancelCountdown(),
      onPointerSignal: (_) => _cancelCountdown(),
      child: DraggableScrollableSheet(
        controller: _draggableController,
        initialChildSize: 0.95,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        snap: true,
        snapSizes: const [0.95],
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Material(
              color: theme.colorScheme.surface,
              child: Navigator(
                key: _sheetNavKey,
                onGenerateRoute: (settings) {
                  return MaterialPageRoute(
                    builder: (_) => _ReviewListPage(
                      batch: widget.batch,
                      overrides: _episodeOverrides,
                      skippedEpisodes: _skippedEpisodes,
                      unresolved: _unresolvedIssues,
                      countdown: _countdown,
                      countdownActive: _countdownActive,
                      onStart: _start,
                      onCancel: _cancel,
                      onSwapEpisode: _openPicker,
                      onSkipEpisode: _skipEpisode,
                      onUndoSkip: _undoSkip,
                      scrollController: scrollController,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReviewListPage extends StatelessWidget {
  final PreparedDownloadBatch batch;
  final Map<int, PreparedTorrentDownloadJob> overrides;
  final Set<int> skippedEpisodes;
  final List<NyaaEpisodeResolutionIssue> unresolved;
  final Animation<double> countdown;
  final bool countdownActive;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final void Function({
    required int episodeNumber,
    required String episodeTitle,
    required NyaaSearchConfiguration searchConfiguration,
    required String? currentTorrentFilename,
  })
  onSwapEpisode;
  final ValueChanged<int> onSkipEpisode;
  final ValueChanged<int> onUndoSkip;
  final ScrollController scrollController;

  const _ReviewListPage({
    required this.batch,
    required this.overrides,
    required this.skippedEpisodes,
    required this.unresolved,
    required this.countdown,
    required this.countdownActive,
    required this.onStart,
    required this.onCancel,
    required this.onSwapEpisode,
    required this.onSkipEpisode,
    required this.onUndoSkip,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    final totalBytes = items.fold<int>(0, (s, i) => s + i.totalBytes);
    final hasDownloads = items.any((item) => item.job != null);
    final canStart = unresolved.isEmpty;

    return Column(
      children: [
        const _GrabHandle(),
        _Header(
          source: batch.jobs.isNotEmpty ? batch.jobs.first.source.label : 'Nya',
          animeTitle: items
              .firstWhere((i) => i.job != null, orElse: () => _Item.empty())
              .animeTitle,
          totalEpisodes: items.length,
          resolved: items.where((i) => i.status != _Status.unresolved).length,
          totalBytes: totalBytes,
          onCancel: onCancel,
        ),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: items.length + (batch.notices.isNotEmpty ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index >= items.length) {
                return _NoticesBlock(notices: batch.notices);
              }
              final item = items[index];
              return EpisodeReviewRow(
                episodeLabel: item.episodeLabel,
                status: switch (item.status) {
                  _Status.auto => EpisodeReviewStatus.autoPlanned,
                  _Status.manual => EpisodeReviewStatus.manuallySwapped,
                  _Status.unresolved => EpisodeReviewStatus.unresolved,
                  _Status.skipped => EpisodeReviewStatus.skipped,
                },
                torrentName: item.job?.torrentName,
                meta: item.meta,
                unresolvedReason: item.issue?.description,
                isSwappable: item.isSwappable,
                onTap: !item.isSwappable
                    ? null
                    : () => onSwapEpisode(
                        episodeNumber: item.episodeNumber!,
                        episodeTitle: item.animeTitle,
                        searchConfiguration: item.searchConfiguration,
                        currentTorrentFilename: item.job?.torrentName,
                      ),
                onSkip: item.issue == null || item.episodeNumber == null
                    ? null
                    : () => onSkipEpisode(item.episodeNumber!),
                onUndoSkip:
                    item.status != _Status.skipped || item.episodeNumber == null
                    ? null
                    : () => onUndoSkip(item.episodeNumber!),
              );
            },
          ),
        ),
        _Footer(
          countdown: countdown,
          countdownActive: countdownActive,
          canStart: canStart,
          hasDownloads: hasDownloads,
          unresolvedCount: unresolved.length,
          onStart: onStart,
          onCancel: onCancel,
        ),
      ],
    );
  }

  List<_Item> _buildItems() {
    final items = <_Item>[];
    for (final job in batch.jobs) {
      if (job is! PreparedTorrentDownloadJob) {
        items.add(_Item.foreignJob(job));
        continue;
      }
      final meta = job.reviewMetadata;
      if (meta?.isBatch ?? false) {
        items.addAll(_Item.batchEpisodes(job, overrides));
        continue;
      }
      final ep = meta?.episodeNumber;
      if (ep == null) {
        items.add(_Item.foreignJob(job));
        continue;
      }
      final override = overrides[ep];
      items.add(
        _Item.episode(
          episodeNumber: ep,
          job: override ?? job,
          animeTitle: job.animeTitle,
          isManual: override != null,
        ),
      );
    }
    for (final issue in batch.nyaaEpisodeIssues) {
      final override = overrides[issue.episodeNumber];
      if (override != null) {
        // Already represented via the override path above? No — issues are
        // separate from initial jobs. So append.
        items.add(
          _Item.episode(
            episodeNumber: issue.episodeNumber,
            job: override,
            animeTitle: override.animeTitle,
            isManual: true,
            issue: issue,
          ),
        );
      } else if (skippedEpisodes.contains(issue.episodeNumber)) {
        items.add(_Item.skipped(issue));
      } else {
        items.add(_Item.unresolved(issue));
      }
    }
    items.sort((a, b) => (a.sortKey).compareTo(b.sortKey));
    return items;
  }
}

enum _Status { auto, manual, unresolved, skipped }

class _Item {
  final int? episodeNumber;
  final String episodeLabel;
  final PreparedTorrentDownloadJob? job;
  final NyaaEpisodeResolutionIssue? issue;
  final _Status status;
  final bool isSwappable;
  final String animeTitle;
  final NyaaSearchConfiguration searchConfiguration;
  final TorrentMetaData? meta;
  final int totalBytes;
  final int sortKey;

  const _Item({
    required this.episodeNumber,
    required this.episodeLabel,
    required this.job,
    required this.issue,
    required this.status,
    required this.isSwappable,
    required this.animeTitle,
    required this.searchConfiguration,
    required this.meta,
    required this.totalBytes,
    required this.sortKey,
  });

  factory _Item.episode({
    required int episodeNumber,
    required PreparedTorrentDownloadJob job,
    required String animeTitle,
    required bool isManual,
    NyaaEpisodeResolutionIssue? issue,
  }) {
    return _Item(
      episodeNumber: episodeNumber,
      episodeLabel: '$episodeNumber',
      job: job,
      issue: issue,
      status: isManual ? _Status.manual : _Status.auto,
      isSwappable: true,
      animeTitle: animeTitle,
      searchConfiguration:
          job.reviewMetadata?.searchConfiguration ??
          NyaaSearchConfiguration(query: '$animeTitle $episodeNumber'),
      meta: TorrentMetaData.fromJob(job),
      totalBytes: job.totalBytes,
      sortKey: episodeNumber,
    );
  }

  static List<_Item> batchEpisodes(
    PreparedTorrentDownloadJob job,
    Map<int, PreparedTorrentDownloadJob> overrides,
  ) {
    final meta = job.reviewMetadata;
    final episodeNumbers = meta?.batchEpisodeNumbers ?? const [];
    if (episodeNumbers.isEmpty) {
      return [_Item.batchJob(job)];
    }
    return [
      for (final episodeNumber in episodeNumbers)
        _Item(
          episodeNumber: episodeNumber,
          episodeLabel: '$episodeNumber',
          job: overrides[episodeNumber] ?? job,
          issue: null,
          status: overrides.containsKey(episodeNumber)
              ? _Status.manual
              : _Status.auto,
          isSwappable: true,
          animeTitle: job.animeTitle,
          searchConfiguration:
              meta?.searchConfiguration ??
              NyaaSearchConfiguration(
                query: '${job.animeTitle} $episodeNumber',
              ),
          meta: overrides[episodeNumber] == null
              ? TorrentMetaData(
                  episodeNumber: episodeNumber,
                  isBatch: true,
                  resolution: meta?.resolution,
                  languageLabel: meta?.languageLabel,
                  seeders: meta?.seeders,
                  sizeBytes: meta?.batchEpisodeFileSizes[episodeNumber],
                )
              : TorrentMetaData.fromJob(overrides[episodeNumber]!),
          totalBytes:
              overrides[episodeNumber]?.totalBytes ??
              meta?.batchEpisodeFileSizes[episodeNumber] ??
              0,
          sortKey: episodeNumber,
        ),
    ];
  }

  factory _Item.unresolved(NyaaEpisodeResolutionIssue issue) {
    return _Item(
      episodeNumber: issue.episodeNumber,
      episodeLabel: '${issue.episodeNumber}',
      job: null,
      issue: issue,
      status: _Status.unresolved,
      isSwappable: true,
      animeTitle: issue.title,
      searchConfiguration: issue.searchConfiguration,
      meta: null,
      totalBytes: 0,
      sortKey: issue.episodeNumber,
    );
  }

  factory _Item.skipped(NyaaEpisodeResolutionIssue issue) {
    return _Item(
      episodeNumber: issue.episodeNumber,
      episodeLabel: '${issue.episodeNumber}',
      job: null,
      issue: issue,
      status: _Status.skipped,
      isSwappable: true,
      animeTitle: issue.title,
      searchConfiguration: issue.searchConfiguration,
      meta: null,
      totalBytes: 0,
      sortKey: issue.episodeNumber,
    );
  }

  factory _Item.batchJob(PreparedTorrentDownloadJob job) {
    return _Item(
      episodeNumber: null,
      episodeLabel: 'Batch',
      job: job,
      issue: null,
      status: _Status.auto,
      isSwappable: false,
      animeTitle: job.animeTitle,
      searchConfiguration: NyaaSearchConfiguration(query: job.animeTitle),
      meta: TorrentMetaData.fromJob(job),
      totalBytes: job.totalBytes,
      sortKey: -1,
    );
  }

  factory _Item.foreignJob(PreparedDownloadJob job) {
    return _Item(
      episodeNumber: null,
      episodeLabel: '—',
      job: job is PreparedTorrentDownloadJob ? job : null,
      issue: null,
      status: _Status.auto,
      isSwappable: false,
      animeTitle: job.animeTitle,
      searchConfiguration: NyaaSearchConfiguration(query: job.animeTitle),
      meta: job is PreparedTorrentDownloadJob
          ? TorrentMetaData.fromJob(job)
          : null,
      totalBytes: job.totalBytes,
      sortKey: -2,
    );
  }

  factory _Item.empty() => const _Item(
    episodeNumber: null,
    episodeLabel: '',
    job: null,
    issue: null,
    status: _Status.auto,
    isSwappable: false,
    animeTitle: '',
    searchConfiguration: NyaaSearchConfiguration(query: ''),
    meta: null,
    totalBytes: 0,
    sortKey: 0,
  );
}

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String source;
  final String animeTitle;
  final int totalEpisodes;
  final int resolved;
  final int totalBytes;
  final VoidCallback onCancel;

  const _Header({
    required this.source,
    required this.animeTitle,
    required this.totalEpisodes,
    required this.resolved,
    required this.totalBytes,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unresolved = totalEpisodes - resolved;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.rate_review_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Review download plan',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Cancel',
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          if (animeTitle.isNotEmpty) ...[
            Text(
              animeTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PlanStatPill(
                icon: Icons.movie_creation_outlined,
                label: '$totalEpisodes items',
              ),
              PlanStatPill(
                icon: Icons.auto_awesome_rounded,
                label: '$resolved ready',
                color: Colors.green,
              ),
              if (unresolved > 0)
                PlanStatPill(
                  icon: Icons.error_outline_rounded,
                  label: '$unresolved unresolved',
                  color: theme.colorScheme.error,
                ),
              PlanStatPill(
                icon: Icons.save_alt_rounded,
                label: planFormatBytes(totalBytes),
              ),
              PlanStatPill(
                icon: Icons.label_outline_rounded,
                label: source,
                color: theme.colorScheme.tertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final Animation<double> countdown;
  final bool countdownActive;
  final bool canStart;
  final bool hasDownloads;
  final int unresolvedCount;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  const _Footer({
    required this.countdown,
    required this.countdownActive,
    required this.canStart,
    required this.hasDownloads,
    required this.unresolvedCount,
    required this.onStart,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
            const Spacer(),
            if (unresolvedCount > 0) ...[
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  '$unresolvedCount left to resolve',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            AnimatedBuilder(
              animation: countdown,
              builder: (context, _) => CountdownStartButton(
                label: countdownActive
                    ? 'Starting in ${(_autoStartDuration.inSeconds - (countdown.value * _autoStartDuration.inSeconds)).ceil()}s'
                    : hasDownloads
                    ? 'Start download'
                    : 'Done',
                icon: hasDownloads
                    ? Icons.play_arrow_rounded
                    : Icons.check_rounded,
                progress: countdownActive ? countdown.value : null,
                enabled: canStart,
                onPressed: onStart,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticesBlock extends StatelessWidget {
  final List<DownloadNotice> notices;

  const _NoticesBlock({required this.notices});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                'Notes',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final n in notices) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  n.level == DownloadNoticeLevel.warning
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline_rounded,
                  size: 14,
                  color: n.level == DownloadNoticeLevel.warning
                      ? const Color(0xFFD97706)
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (n.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          n.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}
