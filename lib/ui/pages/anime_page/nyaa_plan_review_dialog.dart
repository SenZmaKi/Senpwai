import 'dart:async';

import 'package:flutter/material.dart';
import 'package:senpwai/downloads/anime_download_session.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_manual_resolution_panel.dart';

class NyaaPlanReviewDialog extends StatefulWidget {
  final PreparedDownloadBatch batch;
  final AnimeDownloadSessionNotifier notifier;

  const NyaaPlanReviewDialog({
    super.key,
    required this.batch,
    required this.notifier,
  });

  static Future<PreparedDownloadBatch?> review(
    BuildContext context, {
    required PreparedDownloadBatch batch,
    required AnimeDownloadSessionNotifier notifier,
  }) {
    return showDialog<PreparedDownloadBatch>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          NyaaPlanReviewDialog(batch: batch, notifier: notifier),
    );
  }

  @override
  State<NyaaPlanReviewDialog> createState() => _NyaaPlanReviewDialogState();
}

class _NyaaPlanReviewDialogState extends State<NyaaPlanReviewDialog> {
  final _searchController = TextEditingController();
  final Map<int, _IssueSearchState> _issueStates = {};
  final Map<int, PreparedTorrentDownloadJob> _resolvedJobs = {};
  final Set<int> _resolvingEpisodes = {};
  Timer? _debounce;
  int _selectedIssueIndex = 0;

  List<NyaaEpisodeResolutionIssue> get _issues =>
      widget.batch.nyaaEpisodeIssues;

  _IssueSearchState _stateFor(NyaaEpisodeResolutionIssue issue) {
    return _issueStates.putIfAbsent(
      issue.episodeNumber,
      () => _IssueSearchState(query: issue.initialQuery),
    );
  }

  @override
  void initState() {
    super.initState();
    if (_issues.isNotEmpty) {
      final initialIssue = _issues.first;
      _searchController.text = _stateFor(initialIssue).query;
      unawaited(_performSearch(initialIssue));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool get _allIssuesResolved =>
      _issues.every((issue) => _resolvedJobs.containsKey(issue.episodeNumber));

  Future<void> _performSearch(NyaaEpisodeResolutionIssue issue) async {
    final state = _stateFor(issue);
    final query = state.query.trim();
    setState(() {
      state.isLoading = true;
      state.errorText = null;
    });
    if (query.isEmpty) {
      setState(() {
        state.isLoading = false;
        state.results = const [];
      });
      return;
    }

    try {
      final results = await widget.notifier.searchNyaaManualCandidates(
        episodeNumber: issue.episodeNumber,
        query: query,
        filters: state.filters,
      );
      if (!mounted) return;
      setState(() {
        state.isLoading = false;
        state.results = results;
      });
    } on DownloadUserError catch (error) {
      if (!mounted) return;
      setState(() {
        state.isLoading = false;
        state.errorText = error.description;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        state.isLoading = false;
        state.errorText = error.toString();
      });
    }
  }

  void _selectIssue(int index) {
    final issue = _issues[index];
    final state = _stateFor(issue);
    setState(() {
      _selectedIssueIndex = index;
      _searchController.text = state.query;
    });
    if (state.results.isEmpty && !state.isLoading) {
      unawaited(_performSearch(issue));
    }
  }

  void _updateQuery(String value) {
    final issue = _issues[_selectedIssueIndex];
    final state = _stateFor(issue);
    state.query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_performSearch(issue));
    });
  }

  void _updateFilters(NyaaManualSearchFilters filters) {
    final issue = _issues[_selectedIssueIndex];
    final state = _stateFor(issue);
    setState(() {
      state.filters = filters;
    });
    unawaited(_performSearch(issue));
  }

  Future<void> _resolveIssue(NyaaManualSearchCandidate candidate) async {
    final issue = _issues[_selectedIssueIndex];
    final issueState = _stateFor(issue);
    setState(() {
      _resolvingEpisodes.add(issue.episodeNumber);
      issueState.errorText = null;
    });
    try {
      final job = await widget.notifier.planManualNyaaEpisode(
        episodeNumber: issue.episodeNumber,
        candidate: candidate,
      );
      if (!mounted) return;
      setState(() {
        _resolvedJobs[issue.episodeNumber] = job;
      });
    } on DownloadUserError catch (error) {
      if (!mounted) return;
      setState(() {
        issueState.errorText = error.description;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        issueState.errorText = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _resolvingEpisodes.remove(issue.episodeNumber);
        });
      }
    }
  }

  PreparedDownloadBatch _resolvedBatch({required bool includeAllIssues}) {
    final resolvedJobs = _issues
        .where(
          (issue) =>
              includeAllIssues ||
              _resolvedJobs.containsKey(issue.episodeNumber),
        )
        .map((issue) => _resolvedJobs[issue.episodeNumber])
        .whereType<PreparedTorrentDownloadJob>()
        .toList();
    return widget.batch.copyWith(
      jobs: [...widget.batch.jobs, ...resolvedJobs],
      nyaaEpisodeIssues: const [],
    );
  }

  void _queueResolvedBatch() {
    Navigator.of(context).pop(_resolvedBatch(includeAllIssues: true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasIssues = _issues.isNotEmpty;
    final selectedIssue = hasIssues ? _issues[_selectedIssueIndex] : null;
    final selectedState = selectedIssue == null
        ? null
        : _stateFor(selectedIssue);

    return AlertDialog(
      title: Text(hasIssues ? 'Resolve Nyaa plan' : 'Review Nyaa plan'),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: hasIssues ? 1040 : 520),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasIssues
                      ? 'Automatic planning completed what it could. Resolve the remaining episodes below, then queue the final batch.'
                      : 'This is the automatic torrent plan that will be queued.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SummaryChip(
                      label: '${widget.batch.jobs.length} auto-planned',
                      icon: Icons.auto_awesome_rounded,
                    ),
                    if (hasIssues)
                      _SummaryChip(
                        label:
                            '${_resolvedJobs.length}/${_issues.length} resolved',
                        icon: Icons.rule_folder_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final job in widget.batch.jobs) ...[
                  _PlanJobTile(job: job),
                  const SizedBox(height: 10),
                ],
                if (widget.batch.notices.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Notes',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final notice in widget.batch.notices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '• ${notice.title}${notice.description == null ? '' : ': ${notice.description}'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
                if (selectedIssue != null && selectedState != null) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 560,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 760;
                        final issueList = _IssueList(
                          issues: _issues,
                          selectedIssueIndex: _selectedIssueIndex,
                          resolvedEpisodes: _resolvedJobs.keys.toSet(),
                          onSelected: _selectIssue,
                        );
                        final panel = NyaaManualResolutionPanel(
                          issue: selectedIssue,
                          searchController: _searchController,
                          filters: selectedState.filters,
                          results: selectedState.results,
                          isLoading: selectedState.isLoading,
                          errorText: selectedState.errorText,
                          isResolving: _resolvingEpisodes.contains(
                            selectedIssue.episodeNumber,
                          ),
                          resolvedJob:
                              _resolvedJobs[selectedIssue.episodeNumber],
                          onQueryChanged: _updateQuery,
                          onFiltersChanged: _updateFilters,
                          onCandidateSelected: _resolveIssue,
                        );
                        if (isCompact) {
                          return Column(
                            children: [
                              SizedBox(height: 164, child: issueList),
                              const SizedBox(height: 12),
                              Expanded(child: panel),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 260, child: issueList),
                            const SizedBox(width: 16),
                            Expanded(child: panel),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: widget.batch.jobs.isEmpty && _resolvedJobs.isEmpty
              ? null
              : () => Navigator.of(
                  context,
                ).pop(_resolvedBatch(includeAllIssues: false)),
          child: Text(
            hasIssues ? 'Queue resolved downloads' : 'Queue downloads',
          ),
        ),
        if (hasIssues)
          FilledButton(
            onPressed: _allIssuesResolved ? _queueResolvedBatch : null,
            child: const Text('Queue full batch'),
          ),
      ],
    );
  }
}

class _IssueSearchState {
  String query;
  NyaaManualSearchFilters filters = const NyaaManualSearchFilters();
  List<NyaaManualSearchCandidate> results = const [];
  bool isLoading = false;
  String? errorText;

  _IssueSearchState({required this.query});
}

class _IssueList extends StatelessWidget {
  final List<NyaaEpisodeResolutionIssue> issues;
  final int selectedIssueIndex;
  final Set<int> resolvedEpisodes;
  final ValueChanged<int> onSelected;

  const _IssueList({
    required this.issues,
    required this.selectedIssueIndex,
    required this.resolvedEpisodes,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      itemCount: issues.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final issue = issues[index];
        final isSelected = index == selectedIssueIndex;
        final isResolved = resolvedEpisodes.contains(issue.episodeNumber);
        return Material(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.2,
                ),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            mouseCursor: SystemMouseCursors.click,
            onTap: () => onSelected(index),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Episode ${issue.episodeNumber}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        isResolved
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                        size: 18,
                        color: isResolved
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    issue.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SummaryChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PlanJobTile extends StatelessWidget {
  final PreparedDownloadJob job;

  const _PlanJobTile({required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final torrentJob = job is PreparedTorrentDownloadJob
        ? job as PreparedTorrentDownloadJob
        : null;
    final reviewMetadata = torrentJob?.reviewMetadata;
    final tags = <String>[
      if (reviewMetadata?.episodeNumber case final episodeNumber?)
        'Episode $episodeNumber',
      if (reviewMetadata?.isBatch ?? false) 'Batch torrent',
      if (reviewMetadata?.resolution case final resolution?)
        resolution.toString(),
      if (reviewMetadata?.languageLabel case final languageLabel?)
        languageLabel,
      if (reviewMetadata?.seeders case final seeders?) '$seeders seeders',
      _formatBytes(job.totalBytes),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            torrentJob?.torrentName ?? job.displayTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            job.source.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: theme.colorScheme.surfaceContainerLow,
                    ),
                    child: Text(
                      tag,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}
