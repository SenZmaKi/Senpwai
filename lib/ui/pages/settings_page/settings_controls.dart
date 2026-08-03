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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            borderRadius: BorderRadius.circular(10),
            icon: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            dropdownColor: theme.colorScheme.surfaceContainerHigh,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
            items: items,
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ),
      ),
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

enum LimitMode { disabled, limited, unlimited }

class LimitSettingControl extends StatelessWidget {
  final LimitMode mode;
  final ValueChanged<LimitMode> onModeChanged;
  final Widget? valueField;
  final bool allowsDisabled;

  const LimitSettingControl({
    super.key,
    required this.mode,
    required this.onModeChanged,
    this.valueField,
    this.allowsDisabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        SettingsDropdown<LimitMode>(
          value: mode,
          items: [
            const DropdownMenuItem(
              value: LimitMode.unlimited,
              child: Text('Unlimited'),
            ),
            const DropdownMenuItem(
              value: LimitMode.limited,
              child: Text('Custom Limit'),
            ),
            if (allowsDisabled)
              const DropdownMenuItem(
                value: LimitMode.disabled,
                child: Text('Disabled'),
              ),
          ],
          onChanged: onModeChanged,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              axis: Axis.horizontal,
              axisAlignment: -1.0,
              child: child,
            ),
          ),
          child: mode == LimitMode.limited && valueField != null
              ? KeyedSubtree(
                  key: const ValueKey('limit_value_field'),
                  child: valueField!,
                )
              : const SizedBox.shrink(key: ValueKey('limit_value_empty')),
        ),
      ],
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
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
    if (!_focusNode.hasFocus) _commit();
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
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: 104,
      height: 34,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: isDark ? 0.4 : 0.6,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isFocused
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: _isFocused ? 1.5 : 1.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                inputFormatters: [
                  if (widget.allowNegative)
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))
                  else
                    FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
                onSubmitted: (_) => _commit(),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              widget.unit,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
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
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
    if (!_focusNode.hasFocus) _commit();
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
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: 108,
      height: 34,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: isDark ? 0.4 : 0.6,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isFocused
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: _isFocused ? 1.5 : 1.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
                onSubmitted: (_) => _commit(),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              widget.unit,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
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
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
    if (!_focusNode.hasFocus) _commit();
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
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: 200,
      height: 34,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: isDark ? 0.4 : 0.6,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isFocused
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: _isFocused ? 1.5 : 1.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          obscureText: widget.obscureText,
          textAlign: TextAlign.start,
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hintText,
            hintStyle: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 7),
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
          ),
          onSubmitted: (_) => _commit(),
        ),
      ),
    );
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
