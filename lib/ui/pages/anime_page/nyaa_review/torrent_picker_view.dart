import 'dart:async';

import 'package:flutter/material.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_review/torrent_candidate_tile.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_review/torrent_filter_config_view.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_review/torrent_search_controls.dart';

typedef CandidateSearchFn =
    Future<List<NyaaManualSearchCandidate>> Function({
      required String query,
      required NyaaManualSearchFilters filters,
    });

typedef CandidatePlanFn =
    Future<PreparedTorrentDownloadJob> Function(
      NyaaManualSearchCandidate candidate,
    );

class TorrentPickerView extends StatefulWidget {
  final int episodeNumber;
  final String episodeTitle;
  final NyaaSearchConfiguration searchConfiguration;

  /// Filename of the torrent currently selected for this episode (auto or
  /// previously swapped). Highlighted in the results list.
  final String? currentTorrentFilename;

  final NyaaManualSearchFilters filters;
  final ValueChanged<NyaaManualSearchFilters> onFiltersChanged;

  final CandidateSearchFn onSearch;
  final CandidatePlanFn onPlanCandidate;
  final ValueChanged<PreparedTorrentDownloadJob> onResolved;
  final VoidCallback onClose;

  const TorrentPickerView({
    super.key,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.searchConfiguration,
    required this.currentTorrentFilename,
    required this.filters,
    required this.onFiltersChanged,
    required this.onSearch,
    required this.onPlanCandidate,
    required this.onResolved,
    required this.onClose,
  });

  @override
  State<TorrentPickerView> createState() => _TorrentPickerViewState();
}

class _TorrentPickerViewState extends State<TorrentPickerView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  List<NyaaManualSearchCandidate> _rawResults = const [];
  bool _isLoading = false;
  String? _errorText;
  bool _errorCanShowResults = false;
  NyaaManualSearchCandidate? _planningCandidate;
  bool _showingFilters = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchConfiguration.query;
    unawaited(_runSearch());
  }

  @override
  void didUpdateWidget(covariant TorrentPickerView old) {
    super.didUpdateWidget(old);
    if (old.filters != widget.filters) {
      // Filter changes that affect server-side fields → refetch.
      final serverChanged =
          old.filters.exactEpisodeOnly != widget.filters.exactEpisodeOnly ||
          old.filters.sameSeasonOnly != widget.filters.sameSeasonOnly ||
          old.filters.preferredLanguageOnly !=
              widget.filters.preferredLanguageOnly ||
          old.filters.sort != widget.filters.sort;
      if (serverChanged) {
        unawaited(_runSearch());
      } else {
        // Pure FE filter change → re-apply locally, no refetch.
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<NyaaManualSearchCandidate> get _filteredResults =>
      widget.filters.applyClientSide(_rawResults);

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    setState(() {
      _isLoading = true;
      _errorText = null;
      _errorCanShowResults = false;
    });
    if (query.isEmpty) {
      setState(() {
        _isLoading = false;
        _rawResults = const [];
      });
      return;
    }
    try {
      final results = await widget.onSearch(
        query: query,
        filters: widget.filters,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _rawResults = results;
      });
    } on DownloadUserError catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = error.description;
        _errorCanShowResults = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = error.toString();
        _errorCanShowResults = false;
      });
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _runSearch);
  }

  Future<void> _selectCandidate(NyaaManualSearchCandidate c) async {
    setState(() {
      _planningCandidate = c;
      _errorText = null;
      _errorCanShowResults = false;
    });
    try {
      final job = await widget.onPlanCandidate(c);
      if (!mounted) return;
      widget.onResolved(job);
    } on DownloadUserError catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.description;
        _errorCanShowResults = true;
        _planningCandidate = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _errorCanShowResults = true;
        _planningCandidate = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showingFilters) {
      return TorrentFilterConfigView(
        initial: widget.filters,
        onApply: widget.onFiltersChanged,
        onClose: () => setState(() => _showingFilters = false),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          episodeNumber: widget.episodeNumber,
          episodeTitle: widget.episodeTitle,
          currentTorrentFilename: widget.currentTorrentFilename,
          onClose: widget.onClose,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TorrentSearchControls(
            controller: _searchController,
            onQueryChanged: _onQueryChanged,
            onClear: () {
              _searchController.clear();
              _onQueryChanged('');
            },
            filters: widget.filters,
            onSortChanged: (sort) =>
                widget.onFiltersChanged(widget.filters.copyWith(sort: sort)),
            onOpenFilters: () => setState(() => _showingFilters = true),
            onFiltersChanged: widget.onFiltersChanged,
            hintText: 'Search for episode ${widget.episodeNumber}',
          ),
        ),
        Expanded(child: _resultsBody()),
      ],
    );
  }

  Widget _resultsBody() {
    final theme = Theme.of(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorText != null) {
      final canShowResults = _errorCanShowResults && _rawResults.isNotEmpty;
      return _EmptyMessage(
        icon: Icons.error_outline_rounded,
        color: theme.colorScheme.error,
        message: _errorText!,
        actionLabel: canShowResults ? 'Show results' : 'Try again',
        onAction: canShowResults
            ? () => setState(() => _errorText = null)
            : () => unawaited(_runSearch()),
      );
    }
    final filtered = _filteredResults;
    if (filtered.isEmpty) {
      if (_rawResults.isEmpty) {
        return _EmptyMessage(
          icon: Icons.search_off_rounded,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          message:
              'No torrents matched.\nTry editing the search query or relaxing filters.',
        );
      }
      return _EmptyMessage(
        icon: Icons.filter_alt_off_rounded,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
        message:
            '${_rawResults.length} result(s) hidden by filters.\nRelax filters to see them.',
      );
    }
    return Scrollbar(
      controller: _scrollController,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final candidate = filtered[index];
          final isCurrent =
              candidate.result.filename == widget.currentTorrentFilename;
          return TorrentCandidateTile(
            candidate: candidate,
            isSelecting: identical(candidate, _planningCandidate),
            isCurrentlySelected: isCurrent,
            onSelect: () => _selectCandidate(candidate),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int episodeNumber;
  final String episodeTitle;
  final String? currentTorrentFilename;
  final VoidCallback onClose;

  const _Header({
    required this.episodeNumber,
    required this.episodeTitle,
    required this.currentTorrentFilename,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onClose,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Pick a torrent for episode $episodeNumber',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (currentTorrentFilename != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Currently: $currentTorrentFilename',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    episodeTitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

class _EmptyMessage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyMessage({
    required this.icon,
    required this.color,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(
                  actionLabel == 'Try again'
                      ? Icons.refresh_rounded
                      : Icons.list_rounded,
                ),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
