import 'package:logging/logging.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/source_resolver/shared.dart';
import 'package:senpwai/sources/shared/matcher/shared.dart';
import 'package:senpwai/sources/shared/matcher/tokyoinsider.dart';
import 'package:senpwai/sources/tokyoinsider.dart' as tokyoinsider;

final _log = Logger('senpwai.downloads.source_resolver.tokyoinsider');

typedef TokyoinsiderSourceMatch = SourceMatch<tokyoinsider.AnimeResult>;

class TokyoinsiderDownloadSourceResolver {
  final TokyoinsiderMatcher _matcher;

  TokyoinsiderDownloadSourceResolver({TokyoinsiderMatcher? matcher})
    : _matcher = matcher ?? TokyoinsiderMatcher();

  Future<SourceMatchState<TokyoinsiderSourceMatch>> resolve(
    AnilistAnimeBase anime,
  ) {
    return resolveScoredSourceMatch(
      sourceName: 'TokyoInsider',
      logger: _log,
      loadMatches: () => _matcher.match(anime),
    );
  }
}
