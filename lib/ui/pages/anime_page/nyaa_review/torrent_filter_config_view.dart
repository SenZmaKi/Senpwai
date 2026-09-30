import 'package:flutter/material.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';
import 'package:senpwai/sources/shared/matcher/nyaa.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/ui/pages/anime_page/nyaa_plan_components.dart';

const _resolutionOptions = <Resolution>[
  Resolution.res2160p,
  Resolution.res1080p,
  Resolution.res720p,
  Resolution.res480p,
];

const _languageOptions = <NyaaLanguageSignal>[
  NyaaLanguageSignal.dualAudio,
  NyaaLanguageSignal.dubbed,
  NyaaLanguageSignal.subbed,
  NyaaLanguageSignal.unknown,
];

class TorrentFilterConfigView extends StatefulWidget {
  final NyaaManualSearchFilters initial;
  final ValueChanged<NyaaManualSearchFilters> onApply;
  final VoidCallback onClose;

  const TorrentFilterConfigView({
    super.key,
    required this.initial,
    required this.onApply,
    required this.onClose,
  });

  @override
  State<TorrentFilterConfigView> createState() =>
      _TorrentFilterConfigViewState();
}

class _TorrentFilterConfigViewState extends State<TorrentFilterConfigView> {
  late NyaaManualSearchFilters _filters = widget.initial;

  void _update(NyaaManualSearchFilters next) => setState(() => _filters = next);

  void _reset() => _update(const NyaaManualSearchFilters());

  void _apply() {
    widget.onApply(_filters);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(activeCount: _filters.activeCount, onClose: widget.onClose),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              _Section(
                icon: Icons.play_circle_outline_rounded,
                title: 'Episode',
                children: [
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Exact episode only'),
                    subtitle: const Text(
                      'Hide torrents whose parsed episode does not match',
                    ),
                    value: _filters.exactEpisodeOnly,
                    onChanged: (v) =>
                        _update(_filters.copyWith(exactEpisodeOnly: v)),
                  ),
                  _BatchModeSelector(
                    value: _filters.batchMode,
                    onChanged: (v) => _update(_filters.copyWith(batchMode: v)),
                  ),
                ],
              ),
              _Section(
                icon: Icons.language_rounded,
                title: 'Audio',
                children: [
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Preferred audio only'),
                    subtitle: const Text(
                      'Use the audio language you picked for the download',
                    ),
                    value: _filters.preferredLanguageOnly,
                    onChanged: (v) =>
                        _update(_filters.copyWith(preferredLanguageOnly: v)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Allow specific audio signals',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final l in _languageOptions)
                        FilterChip(
                          label: Text(l.label),
                          selected: _filters.languageSignals.contains(l),
                          onSelected: (v) {
                            final next = {..._filters.languageSignals};
                            if (v) {
                              next.add(l);
                            } else {
                              next.remove(l);
                            }
                            _update(_filters.copyWith(languageSignals: next));
                          },
                        ),
                    ],
                  ),
                  if (_filters.languageSignals.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'No restriction — all audio signals allowed.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              _Section(
                icon: Icons.hd_rounded,
                title: 'Resolution',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in _resolutionOptions)
                        FilterChip(
                          label: Text(r.toString()),
                          selected: _filters.resolutions.contains(r),
                          selectedColor: qualityColor(
                            r,
                          ).withValues(alpha: 0.18),
                          checkmarkColor: qualityColor(r),
                          onSelected: (v) {
                            final next = {..._filters.resolutions};
                            if (v) {
                              next.add(r);
                            } else {
                              next.remove(r);
                            }
                            _update(_filters.copyWith(resolutions: next));
                          },
                        ),
                    ],
                  ),
                  if (_filters.resolutions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'No restriction — all resolutions allowed.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              _Section(
                icon: Icons.calendar_view_month_rounded,
                title: 'Season',
                children: [
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Same season only'),
                    subtitle: const Text(
                      'Hide torrents whose parsed season differs from the request',
                    ),
                    value: _filters.sameSeasonOnly,
                    onChanged: (v) =>
                        _update(_filters.copyWith(sameSeasonOnly: v)),
                  ),
                ],
              ),
              _Section(
                icon: Icons.upload_rounded,
                title: 'Seeders',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _filters.minSeeders.clamp(0, 100).toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: _filters.minSeeders == 0
                              ? 'Any'
                              : 'min ${_filters.minSeeders}',
                          onChanged: (v) =>
                              _update(_filters.copyWith(minSeeders: v.round())),
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: Text(
                          _filters.minSeeders == 0
                              ? 'Any'
                              : 'min ${_filters.minSeeders}',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: seederColor(
                              _filters.minSeeders == 0
                                  ? 100
                                  : _filters.minSeeders,
                            ),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _Section(
                icon: Icons.save_alt_rounded,
                title: 'Size',
                children: [
                  _SizeRangeControl(
                    minBytes: _filters.minSizeBytes,
                    maxBytes: _filters.maxSizeBytes,
                    onChanged: (minB, maxB) => _update(
                      _filters.copyWith(
                        minSizeBytes: minB,
                        maxSizeBytes: maxB,
                        clearMinSize: minB == null,
                        clearMaxSize: maxB == null,
                      ),
                    ),
                  ),
                ],
              ),
              _Section(
                icon: Icons.sort_rounded,
                title: 'Sort',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in NyaaManualSearchSort.values)
                        ChoiceChip(
                          label: Text(option.label),
                          selected: _filters.sort == option,
                          onSelected: (v) {
                            if (!v) return;
                            _update(_filters.copyWith(sort: option));
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        _Footer(onReset: _reset, onApply: _apply),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final int activeCount;
  final VoidCallback onClose;

  const _Header({required this.activeCount, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onClose,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Text(
            'Filters',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (activeCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$activeCount active',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final VoidCallback onReset;
  final VoidCallback onApply;

  const _Footer({required this.onReset, required this.onApply});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset'),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onApply,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Apply filters'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _BatchModeSelector extends StatelessWidget {
  final NyaaBatchMode value;
  final ValueChanged<NyaaBatchMode> onChanged;

  const _BatchModeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Batch / single',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final mode in NyaaBatchMode.values)
                ChoiceChip(
                  label: Text(mode.label),
                  selected: value == mode,
                  onSelected: (v) {
                    if (!v) return;
                    onChanged(mode);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SizeRangeControl extends StatelessWidget {
  final int? minBytes;
  final int? maxBytes;
  final void Function(int? min, int? max) onChanged;

  const _SizeRangeControl({
    required this.minBytes,
    required this.maxBytes,
    required this.onChanged,
  });

  static const _maxGb = 20.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minGb = (minBytes ?? 0) / (1024 * 1024 * 1024);
    final maxGb =
        (maxBytes ?? _maxGb.toInt() * 1024 * 1024 * 1024) /
        (1024 * 1024 * 1024);
    final values = RangeValues(
      minGb.clamp(0.0, _maxGb),
      maxGb.clamp(0.0, _maxGb),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RangeSlider(
          values: values,
          min: 0,
          max: _maxGb,
          divisions: 40,
          labels: RangeLabels(
            values.start == 0 ? 'any' : '${values.start.toStringAsFixed(1)} GB',
            values.end >= _maxGb
                ? '${_maxGb.toStringAsFixed(0)}+ GB'
                : '${values.end.toStringAsFixed(1)} GB',
          ),
          onChanged: (range) {
            final min = range.start == 0
                ? null
                : (range.start * 1024 * 1024 * 1024).round();
            final max = range.end >= _maxGb
                ? null
                : (range.end * 1024 * 1024 * 1024).round();
            onChanged(min, max);
          },
        ),
        Row(
          children: [
            Text(
              minBytes == null
                  ? 'Min: any'
                  : 'Min: ${(minBytes! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB',
              style: theme.textTheme.labelMedium,
            ),
            const Spacer(),
            Text(
              maxBytes == null
                  ? 'Max: any'
                  : 'Max: ${(maxBytes! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ],
    );
  }
}
