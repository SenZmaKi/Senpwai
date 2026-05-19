import 'package:logging/logging.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/source_resolver/shared.dart';
import 'package:senpwai/sources/animepahe.dart' as animepahe;
import 'package:senpwai/sources/shared/matcher/animepahe.dart';
import 'package:senpwai/sources/shared/matcher/shared.dart';

final _log = Logger('senpwai.downloads.source_resolver.animepahe');

typedef AnimepaheSourceMatch = SourceMatch<animepahe.AnimeResult>;

class AnimepaheDownloadSourceResolver {
  final AnimepaheMatcher _matcher;

  AnimepaheDownloadSourceResolver({AnimepaheMatcher? matcher})
    : _matcher = matcher ?? AnimepaheMatcher();

  Future<SourceMatchState<AnimepaheSourceMatch>> resolve(
    AnilistAnimeBase anime,
  ) {
    return resolveScoredSourceMatch(
      sourceName: 'AnimePahe',
      logger: _log,
      loadMatches: () => _matcher.match(anime),
    );
  }
}
