import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/ui/pages/anime_page/anime_download_section.dart';
import 'package:senpwai/ui/pages/anime_page/anime_info_header.dart';
import 'package:senpwai/ui/pages/anime_page/anime_page_notifier.dart';
import 'package:senpwai/ui/pages/anime_page/anime_synopsis_section.dart';

class AnimeViewPage extends ConsumerWidget {
  final AnilistAnimeBase anime;

  const AnimeViewPage({super.key, required this.anime});

  static void open(BuildContext context, AnilistAnimeBase anime) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnimeViewPage(anime: anime)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(AnimePageNotifier.provider(anime));
    final notifier = ref.read(AnimePageNotifier.provider(anime).notifier);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Banner + cover + title
          AnimeInfoHeader(anime: anime),
          // Metadata (genres, inline details)
          AnimeMetadataSection(anime: anime),
          // Synopsis
          AnimeSynopsisSection(anime: anime),
          // Download controls
          AnimeDownloadSection(
            notifier: notifier,
            pageState: state,
          ),
        ],
      ),
      // Floating back button
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: FloatingActionButton.small(
          onPressed: () => Navigator.of(context).pop(),
          backgroundColor:
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
          elevation: 2,
          child: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
