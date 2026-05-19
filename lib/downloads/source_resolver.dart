export 'source_resolver/animepahe.dart' show AnimepaheSourceMatch;
export 'source_resolver/shared.dart';
export 'source_resolver/tokyoinsider.dart' show TokyoinsiderSourceMatch;

import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/source_resolver/animepahe.dart';
import 'package:senpwai/downloads/source_resolver/nyaa.dart';
import 'package:senpwai/downloads/source_resolver/shared.dart';
import 'package:senpwai/downloads/source_resolver/tokyoinsider.dart';

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
  static const List<AnimeSource> sourcePriority = [
    AnimeSource.animepahe,
    AnimeSource.tokyoinsider,
    AnimeSource.nyaa,
  ];

  final AnimepaheDownloadSourceResolver _animepaheResolver;
  final TokyoinsiderDownloadSourceResolver _tokyoinsiderResolver;
  final NyaaDownloadSourceResolver _nyaaResolver;

  DownloadSourceResolver({
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
      _animepaheResolver.resolve(anime),
      _tokyoinsiderResolver.resolve(anime),
      _nyaaResolver.resolve(anime),
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
    for (final source in sourcePriority) {
      if (isSourceAvailable(matches, source)) {
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
