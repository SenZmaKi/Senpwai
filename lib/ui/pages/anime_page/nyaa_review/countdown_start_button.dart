import 'package:flutter/material.dart';

/// Filled action button with a circular progress ring sweeping around it
/// during a countdown. Driven by [progress] (0..1). When [progress] is null
/// the ring is hidden — the button looks ordinary.
class CountdownStartButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final double? progress;
  final bool enabled;
  final VoidCallback onPressed;

  const CountdownStartButton({
    super.key,
    required this.label,
    required this.icon,
    required this.progress,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.3);

    return Stack(
      alignment: Alignment.center,
      children: [
        FilledButton.icon(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: const StadiumBorder(),
          ),
          icon: Icon(icon),
          label: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
        if (progress != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RingPainter(
                  progress: progress!.clamp(0.0, 1.0),
                  color: accent,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.height / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3),
      Radius.circular(radius),
    );

    final bg = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(rect, bg);

    if (progress <= 0) return;

    final path = _stadiumPath(rect);
    final metrics = path.computeMetrics().toList();
    final totalLength = metrics.fold<double>(0, (s, m) => s + m.length);
    final targetLength = totalLength * progress;

    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    var consumed = 0.0;
    for (final m in metrics) {
      final remaining = targetLength - consumed;
      if (remaining <= 0) break;
      final extract = remaining >= m.length
          ? m.extractPath(0, m.length)
          : m.extractPath(0, remaining);
      canvas.drawPath(extract, fg);
      consumed += m.length;
    }
  }

  Path _stadiumPath(RRect rect) {
    // Start at the top middle and sweep clockwise so the ring fills from
    // the top, which reads as a clear countdown direction.
    final path = Path()..addRRect(rect);
    // Re-offset start point: rotate the path so it begins at the top center.
    final shifted = Path();
    final metric = path.computeMetrics().first;
    final startOffset = metric.length * 0.25; // top center on a stadium
    final part1 = metric.extractPath(startOffset, metric.length);
    final part2 = metric.extractPath(0, startOffset);
    shifted.addPath(part1, Offset.zero);
    shifted.addPath(part2, Offset.zero);
    return shifted;
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}
