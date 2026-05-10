import 'package:flutter/material.dart';
import 'package:senpwai/ui/pages/anime_page/anime_page_notifier.dart';

// ── Source dropdown ───────────────────────────────────────────────────────────

class SourceDropdown extends StatelessWidget {
  final AnimePageState state;
  final AnimePageNotifier notifier;

  const SourceDropdown({
    super.key,
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = state.selectedSource;
    final accentColor = selected?.color ?? theme.colorScheme.outline;

    return DropdownButtonHideUnderline(
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected != null
              ? accentColor.withValues(alpha: 0.08)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: Border.all(
            color: selected != null
                ? accentColor.withValues(alpha: 0.4)
                : theme.colorScheme.outline.withValues(alpha: 0.25),
            width: selected != null ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButton<AnimeSource>(
          value: state.selectedSource,
          isExpanded: true,
          isDense: true,
          hint: Text(
            'No source available',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          // Custom selected-state rendering (icon + colored label)
          selectedItemBuilder: (_) => AnimeSource.values.map((source) {
            return Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Image.asset(
                    source.iconAsset,
                    width: 16,
                    height: 16,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.public, size: 16, color: source.color),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  source.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: source.color,
                  ),
                ),
              ],
            );
          }).toList(),
          items: AnimeSource.values.map((source) {
            final status = state.sourceStatus(source);
            final isAvailable = state.isSourceAvailable(source);
            final isLoading = status == SourceMatchStatus.loading;
            final sourceColor = source.color;
            return DropdownMenuItem<AnimeSource>(
              value: source,
              enabled: isAvailable,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Opacity(
                      opacity: isAvailable ? 1.0 : 0.35,
                      child: Image.asset(
                        source.iconAsset,
                        width: 16,
                        height: 16,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.public, size: 16, color: sourceColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    source.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isAvailable
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                  if (isLoading) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: sourceColor,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
          onChanged: (source) {
            if (source != null) notifier.selectSource(source);
          },
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class DownloadSectionLabel extends StatelessWidget {
  final String label;
  final IconData? icon;

  const DownloadSectionLabel({super.key, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: labelColor,
    );

    if (icon == null) return Text(label, style: labelStyle);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: labelColor),
        const SizedBox(width: 4),
        Text(label, style: labelStyle),
      ],
    );
  }
}

// ── Dropdown field ────────────────────────────────────────────────────────────

class DownloadDropdown<T> extends StatelessWidget {
  final String label;
  final IconData? icon;
  final List<T> options;
  final T selected;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onSelected;

  const DownloadDropdown({
    super.key,
    required this.label,
    this.icon,
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DownloadSectionLabel(label: label, icon: icon),
        const SizedBox(height: 6),
        DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.25),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<T>(
              value: selected,
              isExpanded: true,
              isDense: true,
              items: options
                  .map(
                    (opt) => DropdownMenuItem<T>(
                      value: opt,
                      child: Text(
                        labelBuilder(opt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) onSelected(val);
              },
            ),
          ),
        ),
      ],
    );
  }
}
