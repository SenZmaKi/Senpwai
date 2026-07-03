import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  const SettingsDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButton<T>(
      value: value,
      underline: const SizedBox.shrink(),
      style: theme.textTheme.bodySmall,
      dropdownColor: theme.colorScheme.surfaceContainerHighest,
      items: items,
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class AsyncSwitch extends StatelessWidget {
  final bool value;
  final FutureOr<void> Function(bool value) onChanged;

  const AsyncSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: (value) {
        final result = onChanged(value);
        if (result is Future<void>) unawaited(result);
      },
    );
  }
}

class NumberSettingField extends StatefulWidget {
  final int value;
  final String unit;
  final int min;
  final int? max;
  final bool allowNegative;
  final int resetToken;
  final ValueChanged<int> onSubmitted;

  const NumberSettingField({
    super.key,
    required this.value,
    required this.unit,
    required this.onSubmitted,
    this.min = 0,
    this.max,
    this.allowNegative = false,
    this.resetToken = 0,
  });

  @override
  State<NumberSettingField> createState() => _NumberSettingFieldState();
}

class _NumberSettingFieldState extends State<NumberSettingField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
    _focusNode = FocusNode()..addListener(_commitWhenBlurred);
  }

  @override
  void didUpdateWidget(covariant NumberSettingField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!_focusNode.hasFocus && widget.value != oldWidget.value) ||
        widget.resetToken != oldWidget.resetToken) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_commitWhenBlurred);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 164,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              inputFormatters: [
                if (widget.allowNegative)
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))
                else
                  FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(isDense: true),
              onSubmitted: (_) => _commit(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: Text(
              widget.unit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _commitWhenBlurred() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text.trim()) ?? 0;
    final shouldClampMin = !widget.allowNegative || parsed >= widget.min;
    final lowerBound = shouldClampMin ? widget.min : parsed;
    final clamped = parsed.clamp(lowerBound, widget.max ?? parsed).toInt();
    _controller.text = clamped.toString();
    widget.onSubmitted(clamped);
  }
}

class DecimalSettingField extends StatefulWidget {
  final double value;
  final String unit;
  final double min;
  final double? max;
  final int fractionDigits;
  final ValueChanged<double> onSubmitted;

  const DecimalSettingField({
    super.key,
    required this.value,
    required this.unit,
    required this.onSubmitted,
    this.min = 0,
    this.max,
    this.fractionDigits = 1,
  });

  @override
  State<DecimalSettingField> createState() => _DecimalSettingFieldState();
}

class _DecimalSettingFieldState extends State<DecimalSettingField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
    _focusNode = FocusNode()..addListener(_commitWhenBlurred);
  }

  @override
  void didUpdateWidget(covariant DecimalSettingField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && widget.value != oldWidget.value) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_commitWhenBlurred);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 164,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.end,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: const InputDecoration(isDense: true),
              onSubmitted: (_) => _commit(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: Text(
              widget.unit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _commitWhenBlurred() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _commit() {
    final parsed = double.tryParse(_controller.text.trim()) ?? widget.min;
    final upperBound = widget.max ?? parsed;
    final clamped = parsed.clamp(widget.min, upperBound).toDouble();
    _controller.text = _format(clamped);
    widget.onSubmitted(clamped);
  }

  String _format(double value) => value.toStringAsFixed(widget.fractionDigits);
}

class TextSettingField extends StatefulWidget {
  final String value;
  final String hintText;
  final bool obscureText;
  final ValueChanged<String> onSubmitted;

  const TextSettingField({
    super.key,
    required this.value,
    required this.onSubmitted,
    this.hintText = '',
    this.obscureText = false,
  });

  @override
  State<TextSettingField> createState() => _TextSettingFieldState();
}

class _TextSettingFieldState extends State<TextSettingField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode()..addListener(_commitWhenBlurred);
  }

  @override
  void didUpdateWidget(covariant TextSettingField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && widget.value != oldWidget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_commitWhenBlurred);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        textAlign: TextAlign.end,
        decoration: InputDecoration(isDense: true, hintText: widget.hintText),
        onSubmitted: (_) => _commit(),
      ),
    );
  }

  void _commitWhenBlurred() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _commit() {
    widget.onSubmitted(_controller.text.trim());
  }
}

class DisabledBadge extends StatelessWidget {
  const DisabledBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Planned',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}
