import 'package:flutter/material.dart';

class BrowserTransportInfoIcon extends StatelessWidget {
  static const message =
      'AnimePahe uses an embedded browser for some requests. It opens only '
      'when needed and may temporarily use more memory.';

  final double size;

  const BrowserTransportInfoIcon({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 350),
      preferBelow: false,
      child: Semantics(
        label: message,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
          ),
          child: Icon(
            Icons.info_outline_rounded,
            size: size - 3,
            color: theme.colorScheme.primary.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
