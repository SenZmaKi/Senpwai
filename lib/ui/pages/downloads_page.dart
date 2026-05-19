import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/ui/pages/downloads_page/download_job_card.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(DownloadManagerNotifier.provider).items;
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;

    if (downloads.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(ext.cardRadius + 8),
                    ),
                    child: Icon(
                      Icons.download_for_offline_outlined,
                      size: 48,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No Downloads Yet',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 280,
                    child: Text(
                      'Queued and active downloads will appear here once you start them from an anime page.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => DownloadJobCard(item: downloads[index]),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemCount: downloads.length,
    );
  }
}
