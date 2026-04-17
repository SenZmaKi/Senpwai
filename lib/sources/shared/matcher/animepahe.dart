import 'package:logging/logging.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/sources/animepahe.dart' as animepahe;
import 'package:senpwai/sources/shared/matcher/shared.dart';

final _log = Logger("senpwai.sources.matcher.animepahe");

class AnimepaheMatcher {
  final animepahe.Source _source;

  AnimepaheMatcher({animepahe.Source? source})
    : _source = source ?? animepahe.Source();

  Future<List<SourceMatch<animepahe.AnimeResult>>> match(
    AnilistAnimeBase<dynamic> anime,
  ) async {
    final titleCandidates = anime.title.toTitleCandidates();
    if (titleCandidates.isEmpty) return [];

    final allMatches = <SourceMatch<animepahe.AnimeResult>>[];
    final seenIds = <int>{};

    final futures = titleCandidates.map((title) async {
      _log.infoWithMetadata(
        "Searching AnimePahe",
        metadata: {"title": title, "anilistId": anime.id},
      );
      try {
        final results = await _source.search(
          params: animepahe.SearchParams(term: title),
        );
        return (title: title, results: results.items);
      } catch (e) {
        _log.warningWithMetadata(
          "AnimePahe search failed for title candidate",
          metadata: {"title": title, "error": e.toString()},
        );
        return (title: title, results: <animepahe.AnimeResult>[]);
      }
    });

    final searchResults = await Future.wait(futures);
    for (final (:title, :results) in searchResults) {
      for (final result in results) {
        if (seenIds.contains(result.id)) continue;
        seenIds.add(result.id);
        final score = bestTitleScore(titleCandidates, result.title);
        allMatches.add(
          SourceMatch(result: result, score: score, matchedTitle: title),
        );
      }
    }

    sortMatches(allMatches, titleCandidates, (r) => r.title);
    _log.fineWithMetadata(
      "AnimePahe matching complete",
      metadata: {
        "anilistId": anime.id,
        "matchCount": allMatches.length,
        "topScore": allMatches.isNotEmpty ? allMatches.first.score : null,
      },
    );
    return allMatches;
  }
}
