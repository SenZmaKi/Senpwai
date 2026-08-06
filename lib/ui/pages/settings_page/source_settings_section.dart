import 'dart:async';

import 'package:flutter/material.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/ui/pages/settings_page/settings_controls.dart';
import 'package:senpwai/ui/pages/settings_page/settings_tile.dart';

class SourceSettingsSection extends StatelessWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;
  final String? searchQuery;

  const SourceSettingsSection({
    super.key,
    required this.settings,
    required this.notifier,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final sources = settings.sources;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroupCard(
          title: 'Provider Priority & Activation',
          icon: Icons.sort_by_alpha_rounded,
          description: 'Drag to reorder source priority or toggle sources',
          searchQuery: searchQuery,
          searchTerms: [
            for (final source in sources.priority)
              '${source.label} source provider ${sources.enabledSources.contains(source) ? 'enabled' : 'disabled'}',
          ],
          children: [
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: sources.priority.length,
              onReorder: (oldIndex, newIndex) {
                final next = [...sources.priority];
                if (newIndex > oldIndex) newIndex -= 1;
                final source = next.removeAt(oldIndex);
                next.insert(newIndex, source);
                unawaited(notifier.setSourcePriority(next));
              },
              itemBuilder: (context, index) {
                final source = sources.priority[index];
                return ReorderableDragStartListener(
                  key: ValueKey(source),
                  index: index,
                  child: SettingsTile(
                    icon: Icons.drag_indicator_rounded,
                    title: source.label,
                    subtitle: sources.enabledSources.contains(source)
                        ? 'Enabled · Priority ${index + 1}'
                        : 'Disabled',
                    searchQuery: searchQuery,
                    trailing: AsyncSwitch(
                      value: sources.enabledSources.contains(source),
                      onChanged: (enabled) {
                        final next = {...sources.enabledSources};
                        enabled ? next.add(source) : next.remove(source);
                        return notifier.setEnabledSources(next);
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        SettingsGroupCard(
          title: 'Nyaa Search & Filtering',
          icon: Icons.filter_alt_outlined,
          description:
              'Default filters and sorting applied to Nyaa torrent searches',
          searchQuery: searchQuery,
          searchTerms: const [
            'Exact Episode Only prefer results parsed requested episode',
            'Same Season Only filter manual results inferred season',
            'Manual Sort Order',
            'Minimum Seeders required',
            'Skip review when no episode needs reconciliation',
            'Skip unavailable episodes during reconciliation',
          ],
          children: [
            _NyaaDefaultsList(
              settings: settings,
              notifier: notifier,
              searchQuery: searchQuery,
            ),
          ],
        ),
      ],
    );
  }
}

class _NyaaDefaultsList extends StatelessWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;
  final String? searchQuery;

  const _NyaaDefaultsList({
    required this.settings,
    required this.notifier,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final filters = settings.sources.nyaaDefaultFilters;
    return Column(
      children: [
        SettingsTile(
          icon: Icons.playlist_remove_rounded,
          title: 'Skip Review When Ready',
          subtitle:
              'Start Nyaa downloads directly when no episode needs reconciliation',
          keywords: 'nyaa review plan automatic skip reconciliation',
          searchQuery: searchQuery,
          trailing: AsyncSwitch(
            value: settings.sources.skipNyaaReviewWhenUnambiguous,
            onChanged: notifier.setSkipNyaaReviewWhenUnambiguous,
          ),
        ),
        SettingsTile(
          icon: Icons.next_plan_outlined,
          title: 'Skip Unavailable Episodes',
          subtitle:
              'Default unresolved Nyaa episodes to skipped during reconciliation',
          keywords:
              'nyaa unavailable missing episode skip reconciliation default',
          searchQuery: searchQuery,
          trailing: AsyncSwitch(
            value: settings.sources.skipUnavailableNyaaEpisodes,
            onChanged: notifier.setSkipUnavailableNyaaEpisodes,
          ),
        ),
        SettingsTile(
          icon: Icons.filter_alt_outlined,
          title: 'Exact Episode Only',
          subtitle: 'Prefer results parsed as the requested episode',
          keywords: 'nyaa episode search filter',
          searchQuery: searchQuery,
          trailing: AsyncSwitch(
            value: filters.exactEpisodeOnly,
            onChanged: (value) => notifier.setNyaaDefaultFilters(
              filters.copyWith(exactEpisodeOnly: value),
            ),
          ),
        ),
        SettingsTile(
          icon: Icons.calendar_view_month_rounded,
          title: 'Same Season Only',
          subtitle: 'Filter manual results to the inferred season',
          keywords: 'nyaa season search filter',
          searchQuery: searchQuery,
          trailing: AsyncSwitch(
            value: filters.sameSeasonOnly,
            onChanged: (value) => notifier.setNyaaDefaultFilters(
              filters.copyWith(sameSeasonOnly: value),
            ),
          ),
        ),
        SettingsTile(
          icon: Icons.sort_rounded,
          title: 'Manual Sort Order',
          subtitle: filters.sort.label,
          keywords: 'nyaa sort order manual search',
          searchQuery: searchQuery,
          trailing: SettingsDropdown<NyaaManualSearchSort>(
            value: filters.sort,
            items: [
              for (final value in NyaaManualSearchSort.values)
                DropdownMenuItem(value: value, child: Text(value.label)),
            ],
            onChanged: (value) => unawaited(
              notifier.setNyaaDefaultFilters(filters.copyWith(sort: value)),
            ),
          ),
        ),
        SettingsTile(
          icon: Icons.people_alt_outlined,
          title: 'Minimum Seeders',
          subtitle: '${filters.minSeeders} seeders required',
          keywords: 'nyaa seeders minimum search filter',
          searchQuery: searchQuery,
          trailing: NumberSettingField(
            value: filters.minSeeders,
            unit: 'seeders',
            onSubmitted: (value) => unawaited(
              notifier.setNyaaDefaultFilters(
                filters.copyWith(minSeeders: value),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
