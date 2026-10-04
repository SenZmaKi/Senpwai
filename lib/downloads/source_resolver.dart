export 'source_resolver/animeheaven.dart' show AnimeheavenSourceMatch;
export 'source_resolver/animepahe.dart' show AnimepaheSourceMatch;
export 'source_resolver/shared.dart';
export 'source_resolver/tokyoinsider.dart' show TokyoinsiderSourceMatch;

import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/source_resolver/animeheaven.dart';
import 'package:senpwai/downloads/source_resolver/animepahe.dart';
import 'package:senpwai/downloads/source_resolver/nyaa.dart';
import 'package:senpwai/downloads/source_resolver/shared.dart';
import 'package:senpwai/downloads/source_resolver/tokyoinsider.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/performance_trace.dart';

class ResolvedSourceMatches {
  final SourceMatchState<AnimeheavenSourceMatch> animeheavenMatch;
  final SourceMatchState<AnimepaheSourceMatch> animepaheMatch;
  final SourceMatchState<TokyoinsiderSourceMatch> tokyoinsiderMatch;
  final SourceMatchState<bool> nyaaMatch;

  const ResolvedSourceMatches({
    required this.animeheavenMatch,
    required this.animepaheMatch,
    required this.tokyoinsiderMatch,
    required this.nyaaMatch,
  });
}

class DownloadSourceResolver {
  final SourcePreferences settings;
  final AnimeheavenDownloadSourceResolver _animeheavenResolver;
  final AnimepaheDownloadSourceResolver _animepaheResolver;
  final TokyoinsiderDownloadSourceResolver _tokyoinsiderResolver;
  final NyaaDownloadSourceResolver _nyaaResolver;

  DownloadSourceResolver({
    this.settings = const SourcePreferences(),
    AnimeheavenDownloadSourceResolver? animeheavenResolver,
    AnimepaheDownloadSourceResolver? animepaheResolver,
    TokyoinsiderDownloadSourceResolver? tokyoinsiderResolver,
    NyaaDownloadSourceResolver? nyaaResolver,
  }) : _animeheavenResolver =
           animeheavenResolver ?? AnimeheavenDownloadSourceResolver(),
       _animepaheResolver =
           animepaheResolver ?? AnimepaheDownloadSourceResolver(),
       _tokyoinsiderResolver =
           tokyoinsiderResolver ?? TokyoinsiderDownloadSourceResolver(),
       _nyaaResolver = nyaaResolver ?? NyaaDownloadSourceResolver();

  Future<ResolvedSourceMatches> resolveAll(AnilistAnimeBase anime) async {
    final results = await Future.wait<dynamic>([
      settings.enabledSources.contains(AnimeSource.animeheaven)
          ? traceAsync(
              'anime_sources.animeheaven',
              () => _animeheavenResolver.resolve(anime),
              arguments: {'anilistId': anime.id},
            )
          : Future.value(
              const SourceMatchState<AnimeheavenSourceMatch>.failed(
                'Source disabled',
              ),
            ),
      settings.enabledSources.contains(AnimeSource.animepahe)
          ? traceAsync(
              'anime_sources.animepahe',
              () => _animepaheResolver.resolve(anime),
              arguments: {'anilistId': anime.id},
            )
          : Future.value(
              const SourceMatchState<AnimepaheSourceMatch>.failed(
                'Source disabled',
              ),
            ),
      settings.enabledSources.contains(AnimeSource.tokyoinsider)
          ? traceAsync(
              'anime_sources.tokyoinsider',
              () => _tokyoinsiderResolver.resolve(anime),
              arguments: {'anilistId': anime.id},
            )
          : Future.value(
              const SourceMatchState<TokyoinsiderSourceMatch>.failed(
                'Source disabled',
              ),
            ),
      settings.enabledSources.contains(AnimeSource.nyaa)
          ? traceAsync(
              'anime_sources.nyaa',
              () => _nyaaResolver.resolve(anime),
              arguments: {'anilistId': anime.id},
            )
          : Future.value(
              const SourceMatchState<bool>.failed('Source disabled'),
            ),
    ]);
    return ResolvedSourceMatches(
      animeheavenMatch: results[0] as SourceMatchState<AnimeheavenSourceMatch>,
      animepaheMatch: results[1] as SourceMatchState<AnimepaheSourceMatch>,
      tokyoinsiderMatch:
          results[2] as SourceMatchState<TokyoinsiderSourceMatch>,
      nyaaMatch: results[3] as SourceMatchState<bool>,
    );
  }

  AnimeSource? selectPreferredSource({
    required ResolvedSourceMatches matches,
    required bool sourceSelectedByUser,
    required AnimeSource? selectedSource,
  }) {
    if (sourceSelectedByUser &&
        selectedSource != null &&
        isSourceAvailable(matches, selectedSource)) {
      return selectedSource;
    }
    for (final source in settings.priority) {
      if (settings.enabledSources.contains(source) &&
          isSourceAvailable(matches, source)) {
        return source;
      }
    }
    return null;
  }

  bool isSourceAvailable(ResolvedSourceMatches matches, AnimeSource source) =>
      switch (source) {
        AnimeSource.animeheaven => matches.animeheavenMatch.isMatched,
        AnimeSource.animepahe => matches.animepaheMatch.isMatched,
        AnimeSource.tokyoinsider => matches.tokyoinsiderMatch.isMatched,
        AnimeSource.nyaa => matches.nyaaMatch.isMatched,
      };
}
