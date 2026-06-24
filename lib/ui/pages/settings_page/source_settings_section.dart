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

  const SourceSettingsSection({
    super.key,
    required this.settings,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final sources = settings.sources;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                    ? 'Enabled, priority ${index + 1}'
                    : 'Disabled',
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
        const SizedBox(height: 8),
        _NyaaDefaults(settings: settings, notifier: notifier),
      ],
    );
  }
}

class _NyaaDefaults extends StatelessWidget {
  final AppSettings settings;
  final AppSettingsNotifier notifier;

  const _NyaaDefaults({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final filters = settings.sources.nyaaDefaultFilters;
    return Column(
      children: [
        SettingsTile(
          icon: Icons.filter_alt_outlined,
          title: 'Nyaa Exact Episode',
          subtitle: 'Prefer results parsed as the requested episode',
          trailing: AsyncSwitch(
            value: filters.exactEpisodeOnly,
            onChanged: (value) => notifier.setNyaaDefaultFilters(
              filters.copyWith(exactEpisodeOnly: value),
            ),
          ),
        ),
        SettingsTile(
          icon: Icons.calendar_view_month_rounded,
          title: 'Nyaa Same Season',
          subtitle: 'Filter manual results to the inferred season',
          trailing: AsyncSwitch(
            value: filters.sameSeasonOnly,
            onChanged: (value) => notifier.setNyaaDefaultFilters(
              filters.copyWith(sameSeasonOnly: value),
            ),
          ),
        ),
        SettingsTile(
          icon: Icons.sort_rounded,
          title: 'Nyaa Manual Sort',
          subtitle: filters.sort.label,
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
          subtitle: '${filters.minSeeders}',
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
