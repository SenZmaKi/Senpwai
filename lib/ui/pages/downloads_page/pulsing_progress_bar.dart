import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A determinate progress bar with a horizontal "energy" band that sweeps
/// across the filled portion to convey live download motion.
/// Falls back to a full-width sweep when [value] is null (indeterminate).
class PulsingProgressBar extends StatefulWidget {
  final double? value;
  final double height;
  final Color color;
  final Color trackColor;
  final Color pulseColor;
  final bool pulsing;
  final BorderRadius borderRadius;
  final Duration pulseDuration;

  const PulsingProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.trackColor,
    required this.pulseColor,
    this.height = 8,
    this.pulsing = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.pulseDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<PulsingProgressBar> createState() => _PulsingProgressBarState();
}

class _PulsingProgressBarState extends State<PulsingProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _displayedValue = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.pulseDuration);
    _displayedValue = (widget.value ?? 0).clamp(0.0, 1.0);
    _updateAnimation();
  }

  @override
  void didUpdateWidget(covariant PulsingProgressBar old) {
    super.didUpdateWidget(old);
    if (widget.pulseDuration != old.pulseDuration) {
      _ctrl.duration = widget.pulseDuration;
    }
    _updateAnimation();
  }

  void _updateAnimation() {
    final shouldRun = widget.pulsing;
    if (shouldRun && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!shouldRun && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = (widget.value ?? 0).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _displayedValue, end: target),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      onEnd: () => _displayedValue = target,
      builder: (_, value, __) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            return ClipRRect(
              borderRadius: widget.borderRadius,
              child: CustomPaint(
                size: Size.fromHeight(widget.height),
                painter: _BarPainter(
                  value: widget.value == null ? null : value,
                  color: widget.color,
                  trackColor: widget.trackColor,
                  pulseColor: widget.pulseColor,
                  phase: _ctrl.value,
                  pulsing: widget.pulsing,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: widget.height,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BarPainter extends CustomPainter {
  final double? value;
  final Color color;
  final Color trackColor;
  final Color pulseColor;
  final double phase;
  final bool pulsing;

  _BarPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.pulseColor,
    required this.phase,
    required this.pulsing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    canvas.drawRect(fullRect, Paint()..color = trackColor);

    final fillWidth = value == null ? size.width : value!.clamp(0, 1) * size.width;
    if (fillWidth <= 0) return;

    final fillRect = Rect.fromLTWH(0, 0, fillWidth, size.height);
    canvas.drawRect(fillRect, Paint()..color = color);

    if (!pulsing) return;
    final bandWidth = math.max(60.0, fillWidth * 0.45);
    final centerX = -bandWidth + phase * (fillWidth + bandWidth * 2);
    final bandRect = Rect.fromLTWH(
      centerX - bandWidth / 2,
      0,
      bandWidth,
      size.height,
    );
    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        pulseColor.withValues(alpha: 0),
        pulseColor,
        pulseColor.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(bandRect);
    final paint = Paint()..shader = shader;
    canvas.save();
    canvas.clipRect(fillRect);
    canvas.drawRect(bandRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.pulseColor != pulseColor ||
      old.phase != phase ||
      old.pulsing != pulsing;
}
