import 'package:flutter/material.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              issue.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(issue.description, style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Exact episode'),
                  selected: filters.exactEpisodeOnly,
                  onSelected: (selected) => onFiltersChanged(
                    filters.copyWith(exactEpisodeOnly: selected),
                  ),
                ),
                FilterChip(
                  label: const Text('Same season'),
                  selected: filters.sameSeasonOnly,
                  onSelected: (selected) => onFiltersChanged(
                    filters.copyWith(sameSeasonOnly: selected),
                  ),
                ),
                FilterChip(
                  label: const Text('Preferred audio'),
                  selected: filters.preferredLanguageOnly,
                  onSelected: (selected) => onFiltersChanged(
                    filters.copyWith(preferredLanguageOnly: selected),
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
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.4,
                  ),
                ),
                child: Text(
                  'Selected torrent: ${resolvedJob!.torrentName}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (errorText != null) {
                    return Center(
                      child: Text(
                        errorText!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    );
                  }
                  if (results.isEmpty) {
                    return Center(
                      child: Text(
                        'No torrents matched these filters. Try relaxing them or editing the search query.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
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
                },
              ),
            ),
          ],
        ),
      ),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.22,
        ),
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
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                label: candidate.matchesRequestedEpisode
                    ? 'Episode ${candidate.parsedEpisodeNumber}'
                    : candidate.isBatch
                    ? 'Batch'
                    : 'Episode ${candidate.parsedEpisodeNumber ?? '?'}',
              ),
              _MetaChip(
                label: candidate.resolution?.toString() ?? 'Unknown res',
              ),
              _MetaChip(label: candidate.languageSignal.label),
              _MetaChip(label: '${candidate.result.seeders} seeders'),
              _MetaChip(label: _formatBytes(candidate.result.sizeBytes)),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: isResolving ? null : onSelected,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Use torrent'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Text(label),
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
