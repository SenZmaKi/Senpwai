import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/ui/pages/downloads_page/active_download_card.dart';
import 'package:senpwai/ui/pages/downloads_page/history_download_card.dart';

class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  bool _historyExpanded = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(DownloadManagerNotifier.provider);
    final notifier = ref.read(DownloadManagerNotifier.provider.notifier);
    final theme = Theme.of(context);

    final activeItems = state.items
        .where((i) => !i.status.isTerminal)
        .toList();
    final historyItems = state.items
        .where((i) => i.status.isTerminal)
        .toList();

    // Auto-collapse history when active downloads exist and user hasn't toggled
    if (activeItems.isNotEmpty && historyItems.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_historyExpanded) setState(() => _historyExpanded = true);
      });
    }

    if (activeItems.isEmpty && historyItems.isEmpty) {
      return _EmptyState();
    }

    return CustomScrollView(
      slivers: [
        // ── Active section ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _SectionHeader(
              label: 'Active',
              count: activeItems.length,
            ),
          ),
        ),
        if (activeItems.isEmpty)
          const SliverToBoxAdapter(child: _ActiveEmptyHint())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = activeItems[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ActiveDownloadCard(key: ValueKey(item.id), item: item),
                );
              }, childCount: activeItems.length),
            ),
          ),

        // ── History section ───────────────────────────────────────────────────
        if (historyItems.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _SectionHeader(
                label: 'History',
                count: historyItems.length,
                trailing: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: TextButton.icon(
                    onPressed: () => notifier.clearHistory(),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                    label: const Text('Clear all'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
                onToggle: () =>
                    setState(() => _historyExpanded = !_historyExpanded),
                expanded: _historyExpanded,
              ),
            ),
          ),
          if (_historyExpanded)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = historyItems[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: HistoryDownloadCard(
                      key: ValueKey(item.id),
                      item: item,
                    ),
                  );
                }, childCount: historyItems.length),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ] else
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Widget? trailing;
  final VoidCallback? onToggle;
  final bool expanded;

  const _SectionHeader({
    required this.label,
    required this.count,
    this.trailing,
    this.onToggle,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
        if (onToggle != null) ...[
          const SizedBox(width: 4),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onToggle,
              child: Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActiveEmptyHint extends StatelessWidget {
  const _ActiveEmptyHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.2,
          ),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.08),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.download_for_offline_outlined,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 12),
            Text(
              'No active downloads',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.download_for_offline_outlined,
              size: 42,
              color: theme.colorScheme.primary.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 20),
          Text('No Downloads Yet', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          SizedBox(
            width: 260,
            child: Text(
              'Downloads will appear here once you start them from an anime page.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
