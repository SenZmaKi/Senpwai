export 'source_resolver/animepahe.dart' show AnimepaheSourceMatch;
export 'source_resolver/shared.dart';
export 'source_resolver/tokyoinsider.dart' show TokyoinsiderSourceMatch;

import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/source_resolver/animepahe.dart';
import 'package:senpwai/downloads/source_resolver/nyaa.dart';
import 'package:senpwai/downloads/source_resolver/shared.dart';
import 'package:senpwai/downloads/source_resolver/tokyoinsider.dart';
import 'package:senpwai/settings/settings.dart';

class ResolvedSourceMatches {
  final SourceMatchState<AnimepaheSourceMatch> animepaheMatch;
  final SourceMatchState<TokyoinsiderSourceMatch> tokyoinsiderMatch;
  final SourceMatchState<bool> nyaaMatch;

  const ResolvedSourceMatches({
    required this.animepaheMatch,
    required this.tokyoinsiderMatch,
    required this.nyaaMatch,
  });
}

class DownloadSourceResolver {
  final SourcePreferences settings;
  final AnimepaheDownloadSourceResolver _animepaheResolver;
  final TokyoinsiderDownloadSourceResolver _tokyoinsiderResolver;
  final NyaaDownloadSourceResolver _nyaaResolver;

  DownloadSourceResolver({
    this.settings = const SourcePreferences(),
    AnimepaheDownloadSourceResolver? animepaheResolver,
    TokyoinsiderDownloadSourceResolver? tokyoinsiderResolver,
    NyaaDownloadSourceResolver? nyaaResolver,
  }) : _animepaheResolver =
           animepaheResolver ?? AnimepaheDownloadSourceResolver(),
       _tokyoinsiderResolver =
           tokyoinsiderResolver ?? TokyoinsiderDownloadSourceResolver(),
       _nyaaResolver = nyaaResolver ?? NyaaDownloadSourceResolver();

  Future<ResolvedSourceMatches> resolveAll(AnilistAnimeBase anime) async {
    final results = await Future.wait<dynamic>([
      settings.enabledSources.contains(AnimeSource.animepahe)
          ? _animepaheResolver.resolve(anime)
          : Future.value(
              const SourceMatchState<AnimepaheSourceMatch>.failed(
                'Source disabled',
              ),
            ),
      settings.enabledSources.contains(AnimeSource.tokyoinsider)
          ? _tokyoinsiderResolver.resolve(anime)
          : Future.value(
              const SourceMatchState<TokyoinsiderSourceMatch>.failed(
                'Source disabled',
              ),
            ),
      settings.enabledSources.contains(AnimeSource.nyaa)
          ? _nyaaResolver.resolve(anime)
          : Future.value(
              const SourceMatchState<bool>.failed('Source disabled'),
            ),
    ]);
    return ResolvedSourceMatches(
      animepaheMatch: results[0] as SourceMatchState<AnimepaheSourceMatch>,
      tokyoinsiderMatch:
          results[1] as SourceMatchState<TokyoinsiderSourceMatch>,
      nyaaMatch: results[2] as SourceMatchState<bool>,
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
        AnimeSource.animepahe => matches.animepaheMatch.isMatched,
        AnimeSource.tokyoinsider => matches.tokyoinsiderMatch.isMatched,
        AnimeSource.nyaa => matches.nyaaMatch.isMatched,
      };
}
