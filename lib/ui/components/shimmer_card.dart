import 'package:flutter/material.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

class ShimmerCard extends StatefulWidget {
  final double? height;
  final double? borderRadius;

  const ShimmerCard({super.key, this.height, this.borderRadius});

  @override
  State<ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<SenpwaiThemeExtension>()!;
    final radius = widget.borderRadius ?? ext.cardRadius;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(1.0 + 2.0 * _controller.value, 0),
              colors: [ext.shimmerBase, ext.shimmerHighlight, ext.shimmerBase],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
