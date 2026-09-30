import 'package:flutter/material.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';
import 'package:senpwai/sources/shared/matcher/nyaa.dart';
import 'package:senpwai/sources/shared/shared.dart';

class TorrentSearchControls extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;
  final NyaaManualSearchFilters filters;
  final ValueChanged<NyaaManualSearchSort> onSortChanged;
  final VoidCallback onOpenFilters;
  final ValueChanged<NyaaManualSearchFilters> onFiltersChanged;
  final String hintText;

  const TorrentSearchControls({
    super.key,
    required this.controller,
    required this.onQueryChanged,
    required this.onClear,
    required this.filters,
    required this.onSortChanged,
    required this.onOpenFilters,
    required this.onFiltersChanged,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeChips = _activeChips(theme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: onQueryChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            labelText: 'Search Nyaa',
            hintText: hintText,
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _FilterButton(
              activeCount: filters.activeCount,
              onPressed: onOpenFilters,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SortDropdown(
                value: filters.sort,
                onChanged: onSortChanged,
              ),
            ),
          ],
        ),
        if (activeChips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: activeChips),
        ],
      ],
    );
  }

  List<Widget> _activeChips(ThemeData theme) {
    final chips = <Widget>[];

    void add(String label, NyaaManualSearchFilters Function() onRemove) {
      chips.add(
        InputChip(
          label: Text(label),
          onDeleted: () => onFiltersChanged(onRemove()),
          deleteIcon: const Icon(Icons.close_rounded, size: 16),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    if (!filters.exactEpisodeOnly) {
      add(
        'Allow other episodes',
        () => filters.copyWith(exactEpisodeOnly: true),
      );
    }
    if (!filters.sameSeasonOnly) {
      add('Any season', () => filters.copyWith(sameSeasonOnly: true));
    }
    if (!filters.preferredLanguageOnly) {
      add('Any audio', () => filters.copyWith(preferredLanguageOnly: true));
    }
    if (filters.resolutions.isNotEmpty) {
      final list = filters.resolutions.map((r) => r.toString()).join(', ');
      add(
        'Res: $list',
        () => filters.copyWith(resolutions: const <Resolution>{}),
      );
    }
    if (filters.languageSignals.isNotEmpty) {
      final list = filters.languageSignals.map((s) => s.label).join(', ');
      add(
        'Audio: $list',
        () => filters.copyWith(languageSignals: const <NyaaLanguageSignal>{}),
      );
    }
    if (filters.batchMode != NyaaBatchMode.any) {
      add(
        filters.batchMode.label,
        () => filters.copyWith(batchMode: NyaaBatchMode.any),
      );
    }
    if (filters.minSeeders > 0) {
      add(
        'min ${filters.minSeeders} seeders',
        () => filters.copyWith(minSeeders: 0),
      );
    }
    if (filters.minSizeBytes != null || filters.maxSizeBytes != null) {
      final lo = filters.minSizeBytes == null
          ? 'any'
          : '${(filters.minSizeBytes! / (1024 * 1024 * 1024)).toStringAsFixed(1)}G';
      final hi = filters.maxSizeBytes == null
          ? 'any'
          : '${(filters.maxSizeBytes! / (1024 * 1024 * 1024)).toStringAsFixed(1)}G';
      add(
        'Size: $lo–$hi',
        () => filters.copyWith(clearMinSize: true, clearMaxSize: true),
      );
    }
    return chips;
  }
}

class _FilterButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onPressed;

  const _FilterButton({required this.activeCount, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.tune_rounded, size: 18),
          if (activeCount > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$activeCount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    height: 1.1,
                  ),
                ),
              ),
            ),
        ],
      ),
      label: const Text('Filters'),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  final NyaaManualSearchSort value;
  final ValueChanged<NyaaManualSearchSort> onChanged;

  const _SortDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<NyaaManualSearchSort>(
      key: ValueKey(value),
      initialValue: value,
      isDense: true,
      decoration: const InputDecoration(
        labelText: 'Sort',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: [
        for (final option in NyaaManualSearchSort.values)
          DropdownMenuItem(value: option, child: Text(option.label)),
      ],
      onChanged: (value) {
        if (value == null) return;
        onChanged(value);
      },
    );
  }
}
