import 'package:logging/logging.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/sources/tokyoinsider.dart' as tokyoinsider;
import 'package:senpwai/sources/shared/matcher/shared.dart';

final _log = Logger("senpwai.sources.matcher.tokyoinsider");

class TokyoinsiderMatcher {
  final tokyoinsider.Source _source;

  TokyoinsiderMatcher({tokyoinsider.Source? source})
    : _source = source ?? tokyoinsider.Source();

  Future<List<SourceMatch<tokyoinsider.AnimeResult>>> match(
    AnilistAnimeBase<dynamic> anime,
  ) async {
    final titleCandidates = anime.title.toTitleCandidates();
    if (titleCandidates.isEmpty) return [];

    final allMatches = <SourceMatch<tokyoinsider.AnimeResult>>[];
    final seenUrls = <String>{};

    final futures = titleCandidates.map((title) async {
      _log.infoWithMetadata(
        "Searching TokyoInsider",
        metadata: {"title": title, "anilistId": anime.id},
      );
      try {
        final results = await _source.search(
          params: tokyoinsider.SearchParams(term: title),
        );
        return (title: title, results: results);
      } catch (e) {
        _log.warningWithMetadata(
          "TokyoInsider search failed for title candidate",
          metadata: {"title": title, "error": e.toString()},
        );
        return (title: title, results: <tokyoinsider.AnimeResult>[]);
      }
    });

    final searchResults = await Future.wait(futures);
    for (final (:title, :results) in searchResults) {
      for (final result in results) {
        if (seenUrls.contains(result.url)) continue;
        seenUrls.add(result.url);
        final score = bestTitleScore(titleCandidates, result.title);
        allMatches.add(
          SourceMatch(result: result, score: score, matchedTitle: title),
        );
      }
    }

    sortMatches(allMatches, titleCandidates, (r) => r.title);
    _log.fineWithMetadata(
      "TokyoInsider matching complete",
      metadata: {
        "anilistId": anime.id,
        "matchCount": allMatches.length,
        "topScore": allMatches.isNotEmpty ? allMatches.first.score : null,
      },
    );
    return allMatches;
  }
}
