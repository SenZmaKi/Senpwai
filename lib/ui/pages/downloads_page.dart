import 'package:flutter/material.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';
import 'package:senpwai/ui/shared/responsive.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<SenpwaiThemeExtension>()!;
    final mobile = isMobile(context);
    final pad = horizontalPadding(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, mobile ? 12 : 16, pad, 0),
            child: Text('Downloads', style: theme.textTheme.displaySmall),
          ),
        ),
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
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(ext.cardRadius + 8),
                  ),
                  child: Icon(
                    Icons.download_for_offline_outlined,
                    size: 48,
                    color: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 20),
                Text('No Downloads Yet', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                SizedBox(
                  width: 280,
                  child: Text(
                    'Downloaded episodes will appear here.\nBrowse anime and start downloading!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Browse Anime'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
