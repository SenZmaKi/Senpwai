import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/ui/pages/downloads_page/active_batch_panel.dart';
import 'package:senpwai/ui/pages/downloads_page/batch_item_row.dart';
import 'package:senpwai/ui/pages/downloads_page/batch_queue_page.dart';
import 'package:senpwai/ui/pages/downloads_page/cancelled_row_animator.dart';
import 'package:senpwai/ui/pages/downloads_page/download_batch_snapshot.dart';
import 'package:senpwai/ui/pages/downloads_page/downloads_empty_state.dart';
import 'package:senpwai/ui/shared/responsive.dart';

/// Batch-aware Downloads page.
///
/// Top: ActiveBatchPanel (overall progress + controls) + NextInQueueRail.
/// Below: individual download rows for the active batch.
/// A separate Batch Queue page (pushed) hosts the drag-to-reorder list.
class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(DownloadManagerNotifier.provider);
    final snapshots = buildBatchSnapshots(state);

    if (snapshots.isEmpty) return const DownloadsEmptyState();

    // The active batch is the one currently consuming bandwidth.
    // Fall back to the first batch when nothing is active (e.g. all terminal).
    final activeId = state.activeBatchId;
    DownloadBatchSnapshot active = snapshots.first;
    if (activeId != null) {
      for (final s in snapshots) {
        if (s.batch.id == activeId) {
          active = s;
          break;
        }
      }
    }
    final upcoming = <DownloadBatchSnapshot>[
      for (final s in snapshots)
        if (s.batch.id != active.batch.id) s,
    ];
    final queuedCount = upcoming.length;
    final pad = horizontalPadding(context);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, isMobile(context) ? 14 : 18, pad, 14),
          sliver: SliverToBoxAdapter(
            child: ActiveBatchPanel(
              snapshot: active,
              upcoming: upcoming,
              queuedBatchCount: queuedCount,
              onOpenQueue: () => BatchQueueSheet.open(context),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 6),
          sliver: SliverToBoxAdapter(
            child: _ItemsHeader(itemCount: active.items.length),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 28),
          sliver: SliverList.separated(
            itemCount: active.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final item = active.items[i];
              return CancelledRowAnimator(
                key: ValueKey('row-${item.id}'),
                item: item,
                child: BatchItemRow(item: item, position: i + 1),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ItemsHeader extends StatelessWidget {
  final int itemCount;
  const _ItemsHeader({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 2,
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 10),
          Text(
            'INDIVIDUAL DOWNLOADS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '·  $itemCount',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
