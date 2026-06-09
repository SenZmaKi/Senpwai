import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/downloads/models.dart';

/// Wraps a child row so that, when its item enters the cancelled state,
/// it lingers visibly for [lingerBefore] then fades and collapses height
/// over [fadeDuration] before being dismissed from the manager.
class CancelledRowAnimator extends ConsumerStatefulWidget {
  final DownloadQueueItem item;
  final Widget child;

  static const lingerBefore = Duration(milliseconds: 4500);
  static const fadeDuration = Duration(milliseconds: 500);

  const CancelledRowAnimator({
    super.key,
    required this.item,
    required this.child,
  });

  @override
  ConsumerState<CancelledRowAnimator> createState() =>
      _CancelledRowAnimatorState();
}

class _CancelledRowAnimatorState extends ConsumerState<CancelledRowAnimator>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _maybeStart();
  }

  @override
  void didUpdateWidget(covariant CancelledRowAnimator old) {
    super.didUpdateWidget(old);
    _maybeStart();
  }

  void _maybeStart() {
    if (widget.item.status != DownloadQueueStatus.cancelled) return;
    if (_ctrl != null) return;
    _ctrl = AnimationController(
      vsync: this,
      duration: CancelledRowAnimator.fadeDuration,
    );
    _timer = Timer(CancelledRowAnimator.lingerBefore, () {
      if (!mounted) return;
      _ctrl?.forward().whenComplete(() {
        if (!mounted) return;
        ref
            .read(DownloadManagerNotifier.provider.notifier)
            .dismiss(widget.item.id);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    if (ctrl == null) return widget.child;
    return AnimatedBuilder(
      animation: ctrl,
      child: widget.child,
      builder: (_, child) {
        final t = Curves.easeIn.transform(ctrl.value);
        return Align(
          alignment: Alignment.topCenter,
          heightFactor: (1 - t).clamp(0, 1),
          child: Opacity(opacity: (1 - t).clamp(0, 1), child: child),
        );
      },
    );
  }
}
