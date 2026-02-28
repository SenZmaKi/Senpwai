import 'package:flutter/material.dart';

class FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? tooltip;

  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = value != null;

    Widget dropdown = Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.6)
              : theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: 0.06)
            : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          hint: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          items: [
            DropdownMenuItem<T>(
              value: null as T?,
              child: Text(
                'Any',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            ...items,
          ],
          onChanged: onChanged,
          style: theme.textTheme.bodySmall,
          dropdownColor: theme.colorScheme.surfaceContainerHighest,
          icon: Icon(
            Icons.arrow_drop_down,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      dropdown = Tooltip(message: tooltip!, child: dropdown);
    }

    return dropdown;
  }
}
