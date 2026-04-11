import 'package:logging/logging.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/sources/animepahe.dart' as animepahe;
import 'package:senpwai/sources/tokyoinsider.dart' as tokyoinsider;
import 'package:senpwai/sources/shared/fuzzy.dart';
import 'package:senpwai/shared/log.dart';

final _log = Logger("senpwai.sources.matcher");

class Constants {
  /// An anime must have a score of at least this value to be considered a
  /// perfect match.
  static const minPerfectMatchScore = 90;
}

class SourceMatch<T> {
  final T result;
  final int score;
  final String matchedTitle;

  const SourceMatch({
    required this.result,
    required this.score,
    required this.matchedTitle,
  });

  @override
  String toString() =>
      "SourceMatch(result: $result, score: $score, matchedTitle: $matchedTitle)";
}

/// Score a result against all AniList title candidates, returning the best
/// fuzzy title similarity.
int _bestTitleScore(List<String> titleCandidates, String resultTitle) {
  return titleCandidates
      .map((candidate) => titleSimilarity(candidate, resultTitle))
      .reduce((a, b) => a > b ? a : b);
}

/// Sort matches by score descending, with a tiebreaker: when scores are equal,
/// prefer the result whose title is closest in length to the shortest AniList
/// title candidate (more exact match over subset match).
void _sortMatches<T>(
  List<SourceMatch<T>> matches,
  List<String> titleCandidates,
  String Function(T result) getTitle,
) {
  final refLength =
      titleCandidates.map((t) => t.length).reduce((a, b) => a < b ? a : b);
  matches.sort((a, b) {
    final cmp = b.score.compareTo(a.score);
    if (cmp != 0) return cmp;
    final aDiff = (getTitle(a.result).length - refLength).abs();
    final bDiff = (getTitle(b.result).length - refLength).abs();
    return aDiff.compareTo(bDiff);
  });
}

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
        final score = _bestTitleScore(titleCandidates, result.title);
        allMatches.add(
          SourceMatch(result: result, score: score, matchedTitle: title),
        );
      }
    }

    _sortMatches(allMatches, titleCandidates, (r) => r.title);
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
        final score = _bestTitleScore(titleCandidates, result.title);
        allMatches.add(
          SourceMatch(result: result, score: score, matchedTitle: title),
        );
      }
    }

    _sortMatches(allMatches, titleCandidates, (r) => r.title);
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
