import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/ui/pages/downloads_page/batch_queue_card.dart';
import 'package:senpwai/ui/pages/downloads_page/download_batch_snapshot.dart';
import 'package:senpwai/ui/shared/responsive.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

/// Batch Queue bottom modal sheet: reorderable list of every batch.
/// Drag a card to reorder. The top batch is the active one — demoting the
/// active batch pauses its downloads and promotes the new top.
class BatchQueueSheet extends ConsumerWidget {
  const BatchQueueSheet({super.key});

  static Future<void> open(BuildContext context) {
    final theme = Theme.of(context);
    final senpwai = theme.extension<SenpwaiThemeExtension>();
    final radius = (senpwai?.cardRadius ?? 16).toDouble();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      ),
      builder: (_) => const BatchQueueSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final senpwai = theme.extension<SenpwaiThemeExtension>();
    final radius = (senpwai?.cardRadius ?? 16).toDouble();
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
            border: Border(
              top: BorderSide(
                color: senpwai?.cardBorderColor ??
                    theme.colorScheme.outline.withValues(alpha: 0.18),
              ),
            ),
          ),
          child: Column(
            children: [
              const _Grabber(),
              const _Header(),
              const Divider(height: 1),
              Expanded(child: _ReorderList(scrollController: scrollController)),
            ],
          ),
        );
      },
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(DownloadManagerNotifier.provider);
    final count = buildBatchSnapshots(state).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 12, 12),
      child: Row(
        children: [
          Text(
            'Batch queue',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          _CountChip(count: count),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReorderList extends ConsumerWidget {
  final ScrollController scrollController;
  const _ReorderList({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(DownloadManagerNotifier.provider);
    final notifier = ref.read(DownloadManagerNotifier.provider.notifier);
    final snapshots = buildBatchSnapshots(state);
    final theme = Theme.of(context);
    final senpwai = theme.extension<SenpwaiThemeExtension>();
    final pad = horizontalPadding(context);

    if (snapshots.isEmpty) return const _Empty();

    return ReorderableListView.builder(
      scrollController: scrollController,
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 24),
      itemCount: snapshots.length,
      buildDefaultDragHandles: false,
      onReorder: notifier.reorderBatch,
      proxyDecorator: (child, _, __) => Material(
        elevation: 14,
        shadowColor: theme.colorScheme.primary.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(senpwai?.cardRadius ?? 8),
        color: Colors.transparent,
        child: child,
      ),
      itemBuilder: (context, index) {
        final snap = snapshots[index];
        final isActive = snap.batch.id == state.activeBatchId;
        return Padding(
          key: ValueKey(snap.batch.id),
          padding: const EdgeInsets.only(bottom: 12),
          child: BatchQueueCard(
            snapshot: snap,
            isActive: isActive,
            dragHandle: ReorderableDragStartListener(
              index: index,
              child: const BatchQueueDragGrip(),
            ),
          ),
        );
      },
    );
  }
}

class _CountChip extends StatelessWidget {
  final int count;
  const _CountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue_music_rounded,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              'Queue is empty',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start a download from an anime page and it will land here as a batch you can reorder.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
