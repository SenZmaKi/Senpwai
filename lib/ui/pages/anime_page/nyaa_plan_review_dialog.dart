import 'dart:async';

import 'package:flutter/material.dart';
import 'package:senpwai/downloads/anime_download_session.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_manual_resolution_panel.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_plan_components.dart';

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
    final selectedState =
        selectedIssue == null ? null : _stateFor(selectedIssue);
    final resolvedCount = _resolvedJobs.length;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            hasIssues
                ? Icons.rule_folder_rounded
                : Icons.auto_awesome_rounded,
            size: 22,
            color: hasIssues
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(hasIssues ? 'Resolve Nyaa Plan' : 'Review Nyaa Plan'),
        ],
      ),
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PlanStatPill(
                      icon: Icons.auto_awesome_rounded,
                      label: '${widget.batch.jobs.length} auto-planned',
                    ),
                    if (hasIssues)
                      PlanStatPill(
                        icon: Icons.rule_folder_rounded,
                        label: '$resolvedCount / ${_issues.length} resolved',
                        color: resolvedCount == _issues.length
                            ? Colors.green
                            : theme.colorScheme.error,
                      ),
                  ],
                ),
                // ── Issues FIRST ────────────────────────────────────────────
                if (selectedIssue != null && selectedState != null) ...[
                  const SizedBox(height: 22),
                  PlanSectionHeader(
                    icon: Icons.error_outline_rounded,
                    title: 'Unresolved Episodes',
                    count: _issues.length - resolvedCount,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 520,
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
                            SizedBox(width: 256, child: issueList),
                            const SizedBox(width: 16),
                            Expanded(child: panel),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                // ── Auto-planned jobs ────────────────────────────────────────
                if (widget.batch.jobs.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  PlanSectionHeader(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Auto-Planned',
                    count: widget.batch.jobs.length,
                  ),
                  const SizedBox(height: 12),
                  for (final job in widget.batch.jobs) ...[
                    PlanJobTile(job: job),
                    const SizedBox(height: 8),
                  ],
                ],
                // ── Notes ────────────────────────────────────────────────────
                if (widget.batch.notices.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  PlanSectionHeader(
                    icon: Icons.info_outline_rounded,
                    title: 'Notes',
                    count: widget.batch.notices.length,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: 10),
                  for (final notice in widget.batch.notices)
                    _NoticeTile(notice: notice),
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
              : () => Navigator.of(context).pop(
                    _resolvedBatch(includeAllIssues: false),
                  ),
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
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final issue = issues[index];
        final isSelected = index == selectedIssueIndex;
        final isResolved = resolvedEpisodes.contains(issue.episodeNumber);
        final accentColor =
            isResolved ? Colors.green : theme.colorScheme.error;
        return Material(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.2,
                ),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            mouseCursor: SystemMouseCursors.click,
            onTap: () => onSelected(index),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Ep\n${issue.episodeNumber}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issue.title,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          issue.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isResolved
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: accentColor.withValues(
                      alpha: isResolved ? 1.0 : 0.55,
                    ),
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

class _NoticeTile extends StatelessWidget {
  final DownloadNotice notice;

  const _NoticeTile({required this.notice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (notice.level) {
      DownloadNoticeLevel.warning => (
        Icons.warning_amber_rounded,
        const Color(0xFFD97706),
      ),
      DownloadNoticeLevel.info => (
        Icons.info_outline_rounded,
        theme.colorScheme.primary,
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (notice.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    notice.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
