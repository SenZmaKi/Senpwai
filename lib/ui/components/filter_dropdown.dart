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

class MultiSelectDropdown<T> extends StatelessWidget {
  final String label;
  final List<T> selectedValues;
  final List<T> options;
  final String Function(T) optionLabel;
  final ValueChanged<List<T>> onChanged;
  final String? tooltip;

  const MultiSelectDropdown({
    super.key,
    required this.label,
    required this.selectedValues,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    this.tooltip,
  });

  String get _buttonText {
    if (selectedValues.isEmpty) return label;
    if (selectedValues.length == 1) return optionLabel(selectedValues.first);
    return '${selectedValues.length} selected';
  }

  void _showDialog(BuildContext context) {
    final theme = Theme.of(context);
    final selected = List<T>.from(selectedValues);

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(label, style: theme.textTheme.titleMedium),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: options.map((opt) {
                final isChecked = selected.contains(opt);
                return CheckboxListTile(
                  value: isChecked,
                  title: Text(
                    optionLabel(opt),
                    style: theme.textTheme.bodySmall,
                  ),
                  dense: true,
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        selected.add(opt);
                      } else {
                        selected.remove(opt);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setDialogState(() => selected.clear()),
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                onChanged(List<T>.from(selected));
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = selectedValues.isNotEmpty;

    Widget button = GestureDetector(
      onTap: () => _showDialog(context),
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        child: Row(
          children: [
            Expanded(
              child: Text(
                _buttonText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isActive
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}
