import 'package:flutter/material.dart';

class FontAutocomplete extends StatelessWidget {
  final String label;
  final String currentValue;
  final List<String> allFonts;
  final ValueChanged<String> onSelected;

  const FontAutocomplete({
    super.key,
    required this.label,
    required this.currentValue,
    required this.allFonts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: currentValue),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return allFonts;
        return allFonts.where((f) => f.toLowerCase().contains(query)).toList();
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: label, isDense: true),
          onSubmitted: (_) => onSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final theme = Theme.of(context);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option, style: theme.textTheme.bodyMedium),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
