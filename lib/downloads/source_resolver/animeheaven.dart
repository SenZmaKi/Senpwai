import 'package:logging/logging.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/source_resolver/shared.dart';
import 'package:senpwai/sources/animeheaven.dart' as animeheaven;
import 'package:senpwai/sources/shared/matcher/animeheaven.dart';
import 'package:senpwai/sources/shared/matcher/shared.dart';

final _log = Logger('senpwai.downloads.source_resolver.animeheaven');

typedef AnimeheavenSourceMatch = SourceMatch<animeheaven.AnimeResult>;

class AnimeheavenDownloadSourceResolver {
  final AnimeheavenMatcher _matcher;

  AnimeheavenDownloadSourceResolver({AnimeheavenMatcher? matcher})
    : _matcher = matcher ?? AnimeheavenMatcher();

  Future<SourceMatchState<AnimeheavenSourceMatch>> resolve(
    AnilistAnimeBase anime,
  ) {
    return resolveScoredSourceMatch(
      sourceName: 'AnimeHeaven',
      logger: _log,
      loadMatches: () => _matcher.match(anime),
    );
  }
}
