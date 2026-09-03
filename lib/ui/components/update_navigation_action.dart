import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/updates/updates.dart';

class UpdateNavigationAction extends ConsumerWidget {
  final Future<void> Function() onReady;
  final bool showLabel;

  const UpdateNavigationAction({
    super.key,
    required this.onReady,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(UpdateController.provider);
    if (!state.isVisible) return const SizedBox.shrink();
    return Tooltip(
      message: updateTooltip(state),
      child: Semantics(
        button: true,
        label: updateTooltip(state),
        child: MouseRegion(
          cursor: _isActionable(state.phase)
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: InkWell(
            onTap: _isActionable(state.phase)
                ? () => unawaited(handleUpdateAction(ref, state, onReady))
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UpdateNavigationIndicator(state: state),
                  if (showLabel) ...[
                    const SizedBox(height: 4),
                    Text(
                      updateShortLabel(state),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UpdateNavigationIndicator extends StatelessWidget {
  final UpdateState state;

  const UpdateNavigationIndicator({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = state.phase == UpdatePhase.downloading
        ? state.progress
        : state.phase == UpdatePhase.available
        ? 0.0
        : state.phase == UpdatePhase.ready
        ? 1.0
        : null;
    final percentage =
        state.phase == UpdatePhase.downloading && progress != null
        ? '${(progress * 100).round()}%'
        : null;
    return SizedBox.square(
      dimension: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: 36,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.6,
              strokeCap: StrokeCap.round,
              color: state.phase == UpdatePhase.failed
                  ? colorScheme.error
                  : colorScheme.primary,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
            ),
          ),
          if (percentage != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stop_rounded, size: 14, color: colorScheme.primary),
                Text(
                  percentage,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 8,
                    height: 0.9,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            )
          else
            Icon(
              updateIcon(state),
              size: 19,
              color: state.phase == UpdatePhase.failed
                  ? colorScheme.error
                  : colorScheme.primary,
            ),
        ],
      ),
    );
  }
}

Future<void> handleUpdateAction(
  WidgetRef ref,
  UpdateState state,
  Future<void> Function() onReady,
) async {
  final controller = ref.read(UpdateController.provider.notifier);
  switch (state.phase) {
    case UpdatePhase.available:
      await controller.download();
    case UpdatePhase.downloading:
      controller.cancelDownload();
    case UpdatePhase.ready:
      await onReady();
    case UpdatePhase.failed:
      await controller.retry();
    default:
      break;
  }
}

bool _isActionable(UpdatePhase phase) => switch (phase) {
  UpdatePhase.available ||
  UpdatePhase.downloading ||
  UpdatePhase.ready ||
  UpdatePhase.failed => true,
  _ => false,
};

IconData updateIcon(UpdateState state) => switch (state.phase) {
  UpdatePhase.available => Icons.download_rounded,
  UpdatePhase.downloading => Icons.stop_rounded,
  UpdatePhase.verifying => Icons.verified_user_outlined,
  UpdatePhase.preparing => Icons.inventory_2_outlined,
  UpdatePhase.ready =>
    Platform.isAndroid
        ? Icons.system_update_alt_rounded
        : Icons.restart_alt_rounded,
  UpdatePhase.installing => Icons.system_update_rounded,
  UpdatePhase.failed => Icons.refresh_rounded,
  _ => Icons.system_update_rounded,
};

String updateShortLabel(UpdateState state) => switch (state.phase) {
  UpdatePhase.available => 'Update',
  UpdatePhase.downloading => 'Downloading',
  UpdatePhase.verifying => 'Verifying',
  UpdatePhase.preparing => 'Preparing',
  UpdatePhase.ready => Platform.isAndroid ? 'Install' : 'Restart',
  UpdatePhase.installing => 'Installing',
  UpdatePhase.failed => 'Retry',
  _ => 'Update',
};

String updateTooltip(UpdateState state) => switch (state.phase) {
  UpdatePhase.available =>
    'Download ${state.release?.displayVersion ?? 'update'}',
  UpdatePhase.downloading => 'Cancel update download',
  UpdatePhase.verifying => 'Verifying update',
  UpdatePhase.preparing => 'Preparing update',
  UpdatePhase.ready =>
    Platform.isAndroid
        ? 'Install ${state.release?.displayVersion ?? 'update'}'
        : 'Restart to update to ${state.release?.displayVersion ?? 'the new version'}',
  UpdatePhase.installing => 'Installing update',
  UpdatePhase.failed => state.error ?? 'Retry update',
  _ => 'App update',
};
