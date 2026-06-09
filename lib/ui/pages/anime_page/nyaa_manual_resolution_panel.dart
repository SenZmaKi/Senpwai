import 'package:flutter/material.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_plan_components.dart';

class NyaaManualResolutionPanel extends StatelessWidget {
  final NyaaEpisodeResolutionIssue issue;
  final TextEditingController searchController;
  final NyaaManualSearchFilters filters;
  final List<NyaaManualSearchCandidate> results;
  final bool isLoading;
  final String? errorText;
  final bool isResolving;
  final PreparedTorrentDownloadJob? resolvedJob;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<NyaaManualSearchFilters> onFiltersChanged;
  final ValueChanged<NyaaManualSearchCandidate> onCandidateSelected;

  const NyaaManualResolutionPanel({
    super.key,
    required this.issue,
    required this.searchController,
    required this.filters,
    required this.results,
    required this.isLoading,
    required this.errorText,
    required this.isResolving,
    required this.resolvedJob,
    required this.onQueryChanged,
    required this.onFiltersChanged,
    required this.onCandidateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IssueHeader(issue: issue, isResolved: resolvedJob != null),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: searchController,
                    onChanged: onQueryChanged,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      labelText: 'Search Nyaa',
                      hintText: 'Search for episode ${issue.episodeNumber}',
                      suffixIcon: searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                searchController.clear();
                                onQueryChanged('');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Exact episode'),
                        selected: filters.exactEpisodeOnly,
                        onSelected: (v) => onFiltersChanged(
                          filters.copyWith(exactEpisodeOnly: v),
                        ),
                      ),
                      FilterChip(
                        label: const Text('Same season'),
                        selected: filters.sameSeasonOnly,
                        onSelected: (v) => onFiltersChanged(
                          filters.copyWith(sameSeasonOnly: v),
                        ),
                      ),
                      FilterChip(
                        label: const Text('Preferred audio'),
                        selected: filters.preferredLanguageOnly,
                        onSelected: (v) => onFiltersChanged(
                          filters.copyWith(preferredLanguageOnly: v),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<NyaaManualSearchSort>(
                          key: ValueKey(filters.sort),
                          initialValue: filters.sort,
                          decoration: const InputDecoration(labelText: 'Sort'),
                          items: [
                            for (final option in NyaaManualSearchSort.values)
                              DropdownMenuItem(
                                value: option,
                                child: Text(option.label),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            onFiltersChanged(filters.copyWith(sort: value));
                          },
                        ),
                      ),
                    ],
                  ),
                  if (resolvedJob != null) ...[
                    const SizedBox(height: 12),
                    _ResolvedBanner(torrentName: resolvedJob!.torrentName),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: _ResultsList(
                      isLoading: isLoading,
                      errorText: errorText,
                      results: results,
                      isResolving: isResolving,
                      onCandidateSelected: onCandidateSelected,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueHeader extends StatelessWidget {
  final NyaaEpisodeResolutionIssue issue;
  final bool isResolved;

  const _IssueHeader({required this.issue, required this.isResolved});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isResolved ? Colors.green : theme.colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        color: color.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: 0.25)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              isResolved
                  ? Icons.check_circle_rounded
                  : Icons.error_rounded,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  issue.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolvedBanner extends StatelessWidget {
  final String torrentName;

  const _ResolvedBanner({required this.torrentName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.green.withValues(alpha: 0.1),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              torrentName,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.green,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  final bool isLoading;
  final String? errorText;
  final List<NyaaManualSearchCandidate> results;
  final bool isResolving;
  final ValueChanged<NyaaManualSearchCandidate> onCandidateSelected;

  const _ResultsList({
    required this.isLoading,
    required this.errorText,
    required this.results,
    required this.isResolving,
    required this.onCandidateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorText != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 32,
              color: theme.colorScheme.error.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 10),
            Text(
              errorText!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 32,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 10),
            Text(
              'No torrents matched these filters.\nTry relaxing them or editing the search query.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final candidate = results[index];
        return _CandidateTile(
          candidate: candidate,
          isResolving: isResolving,
          onSelected: () => onCandidateSelected(candidate),
        );
      },
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final NyaaManualSearchCandidate candidate;
  final bool isResolving;
  final VoidCallback onSelected;

  const _CandidateTile({
    required this.candidate,
    required this.isResolving,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seeders = candidate.result.seeders;
    final sColor = seederColor(seeders);
    final qColor = qualityColor(candidate.resolution);
    final episodeMatch = candidate.matchesRequestedEpisode;
    final episodeBadgeColor = episodeMatch ? theme.colorScheme.primary : null;
    final episodeLabel =
        candidate.isBatch ? 'Batch' : 'Ep ${candidate.parsedEpisodeNumber ?? '?'}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            candidate.result.filename,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              MetaBadge(
                icon: episodeMatch
                    ? Icons.check_rounded
                    : Icons.play_circle_outline_rounded,
                label: episodeLabel,
                color: episodeBadgeColor,
              ),
              if (candidate.resolution != null)
                MetaBadge(
                  icon: Icons.hd_rounded,
                  label: candidate.resolution!.toString(),
                  color: qColor,
                ),
              MetaBadge(
                icon: Icons.language_rounded,
                label: candidate.languageSignal.label,
              ),
              MetaBadge(
                icon: Icons.upload_rounded,
                label: '$seeders seeders',
                color: sColor,
              ),
              MetaBadge(
                icon: Icons.save_alt_rounded,
                label: planFormatBytes(candidate.result.sizeBytes),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: isResolving ? null : onSelected,
              icon: isResolving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('Use torrent'),
            ),
          ),
        ],
      ),
    );
  }
}

