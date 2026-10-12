import 'dart:async';

import 'package:flutter/material.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/source_resolver.dart';
import 'package:senpwai/tracking/models.dart';
import 'package:senpwai/ui/pages/anime_page/anime_source_ui.dart';

class TrackedSourceControl extends StatefulWidget {
  final TrackedAnime tracked;
  final Set<AnimeSource> enabledSources;
  final List<Widget> trailing;
  final Future<void> Function(AnimeSource?) onChanged;
  final Future<SourceMatchState<Object>> Function(AnimeSource) checkSource;

  const TrackedSourceControl({
    super.key,
    required this.tracked,
    this.enabledSources = const {
      AnimeSource.animeheaven,
      AnimeSource.animepahe,
      AnimeSource.tokyoinsider,
      AnimeSource.nyaa,
    },
    this.trailing = const [],
    required this.onChanged,
    required this.checkSource,
  });

  @override
  State<TrackedSourceControl> createState() => _TrackedSourceControlState();
}

class _TrackedSourceControlState extends State<TrackedSourceControl> {
  int _generation = 0;
  AnimeSource? _pending;
  AnimeSource? _retry;
  String? _message;
  bool _saving = false;
  bool _failed = false;

  @override
  void didUpdateWidget(TrackedSourceControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving &&
        (oldWidget.tracked.anilistId != widget.tracked.anilistId ||
            oldWidget.tracked.preferredSource !=
                widget.tracked.preferredSource ||
            oldWidget.tracked.sourceSelectedByUser !=
                widget.tracked.sourceSelectedByUser)) {
      _generation++;
      _pending = null;
      _retry = null;
      _message = null;
      _failed = false;
    }
  }

  Future<void> _select(AnimeSource? source) async {
    final generation = ++_generation;
    setState(() {
      _pending = source;
      _retry = null;
      _message = source == null ? null : 'Checking ${source.label}…';
      _failed = false;
    });
    try {
      if (source != null) {
        final result = await widget
            .checkSource(source)
            .timeout(const Duration(seconds: 30));
        if (!mounted || generation != _generation) return;
        if (!widget.enabledSources.contains(source)) {
          setState(() {
            _pending = null;
            _failed = true;
            _message = '${source.label} is disabled';
          });
          return;
        }
        if (!result.isMatched) {
          setState(() {
            _pending = null;
            _retry = result.error == 'Source disabled' ? null : source;
            _failed = true;
            _message = result.noMatch
                ? 'Not found on ${source.label}'
                : result.error == 'Source disabled'
                ? '${source.label} is disabled'
                : 'Couldn’t check ${source.label}';
          });
          return;
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() => _saving = true);
      await widget.onChanged(source);
      if (!mounted || generation != _generation) return;
      setState(() {
        _pending = null;
        _saving = false;
        _message = source == null ? null : 'Found · locked to ${source.label}';
      });
    } catch (_) {
      final wasSaving = _saving;
      if (!mounted || generation != _generation) return;
      setState(() {
        _pending = null;
        _saving = false;
        _failed = true;
        _retry = source;
        _message = wasSaving
            ? 'Couldn’t save source'
            : 'Couldn’t check ${source?.label ?? 'source'}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = widget.tracked.sourceSelectedByUser
        ? widget.tracked.preferredSource
        : null;
    final accent = source?.color ?? theme.colorScheme.outline;
    final options = [null, ...AnimeSource.values];
    final control = Tooltip(
      message: 'Choose tracking source',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 180,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: source != null
                ? accent.withValues(alpha: 0.08)
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
            border: Border.all(
              color: accent.withValues(alpha: source != null ? 0.4 : 0.25),
              width: source != null ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: source?.name ?? 'automatic',
              isExpanded: true,
              isDense: true,
              borderRadius: BorderRadius.circular(10),
              dropdownColor: theme.colorScheme.surfaceContainerHigh,
              selectedItemBuilder: (_) => [
                for (final option in options)
                  _SourceLabel(source: option, selected: true),
              ],
              items: [
                for (final option in options)
                  DropdownMenuItem(
                    value: option?.name ?? 'automatic',
                    enabled:
                        option == null ||
                        widget.enabledSources.contains(option),
                    child: Opacity(
                      opacity:
                          option == null ||
                              widget.enabledSources.contains(option)
                          ? 1
                          : 0.35,
                      child: _SourceLabel(source: option),
                    ),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;
                      unawaited(
                        _select(
                          value == 'automatic'
                              ? null
                              : AnimeSource.values.byName(value),
                        ),
                      );
                    },
            ),
          ),
        ),
      ),
    );
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [control, ...widget.trailing],
          ),
          if (_message != null) ...[
            const SizedBox(height: 4),
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  if (_pending != null || _saving) ...[
                    const SizedBox.square(
                      dimension: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      _message!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _failed ? theme.colorScheme.error : null,
                      ),
                    ),
                  ),
                  if (_retry != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => unawaited(_select(_retry)),
                      child: const Text('Retry'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceLabel extends StatelessWidget {
  final AnimeSource? source;
  final bool selected;

  const _SourceLabel({required this.source, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? source?.color : null;
    return Row(
      children: [
        if (source case final source?)
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Image.asset(
              source.iconAsset,
              width: 16,
              height: 16,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.public, size: 16, color: source.color),
            ),
          )
        else
          Icon(Icons.swap_horiz, size: 16, color: theme.colorScheme.onSurface),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            source?.label ?? 'Auto',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: selected ? FontWeight.w700 : null,
              color: color,
            ),
          ),
        ),
        if (selected && source != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.lock_outline, size: 12, color: color),
        ],
      ],
    );
  }
}
