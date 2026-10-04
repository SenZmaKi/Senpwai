import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/sources/animeheaven.dart' as animeheaven;
import 'package:senpwai/sources/shared/fuzzy.dart';
import 'package:senpwai/sources/shared/matcher/shared.dart';

final _log = Logger("senpwai.sources.matcher.animeheaven");

/// Leading results per search whose romaji titles are fetched when no result
/// title equals an AniList title. AnimeHeaven lists some shows under unusual
/// English names (Jujutsu Kaisen is Sorcery Fight), which otherwise lets a
/// subset title such as "Jujutsu Kaisen: The Culling Game" win.
const _titleLookupsPerSearch = 3;

typedef _SearchResults = ({
  String title,
  List<animeheaven.AnimeResult> results,
});

class AnimeheavenMatcher {
  final animeheaven.Source _source;

  AnimeheavenMatcher({animeheaven.Source? source})
    : _source = source ?? animeheaven.Source.getInstance();

  Future<List<SourceMatch<animeheaven.AnimeResult>>> match(
    AnilistAnimeBase<dynamic> anime,
  ) async {
    final titleCandidates = anime.title.toTitleCandidates();
    if (titleCandidates.isEmpty) return [];

    var searchResults = await Future.wait(
      titleCandidates.map((title) async {
        try {
          return (title: title, results: await _source.search(term: title));
        } catch (e) {
          _log.warningWithMetadata(
            "AnimeHeaven search failed for title candidate",
            metadata: {"title": title, "error": e.toString()},
          );
          return (title: title, results: <animeheaven.AnimeResult>[]);
        }
      }),
    );

    var matches = _scoreResults(searchResults, titleCandidates);
    final topResult = matches.firstOrNull?.result;
    if (topResult != null && !_hasExactTitle(topResult, titleCandidates)) {
      searchResults = await _withAlternativeTitles(searchResults);
      matches = _scoreResults(searchResults, titleCandidates);
    }
    _log.fineWithMetadata(
      "AnimeHeaven matching complete",
      metadata: {
        "anilistId": anime.id,
        "matchCount": matches.length,
        "topResult": matches.firstOrNull?.result,
        "topScore": matches.firstOrNull?.score,
      },
    );
    return matches;
  }

  List<SourceMatch<animeheaven.AnimeResult>> _scoreResults(
    List<_SearchResults> searchResults,
    List<String> titleCandidates,
  ) {
    final matches = <SourceMatch<animeheaven.AnimeResult>>[];
    final seenUrls = <String>{};
    for (final (:title, :results) in searchResults) {
      for (final result in results) {
        if (!seenUrls.add(result.url)) continue;
        matches.add(
          SourceMatch(
            result: result,
            score: result.titles
                .map((title) => bestTitleScore(titleCandidates, title))
                .max,
            matchedTitle: title,
          ),
        );
      }
    }
    sortMatches(
      matches,
      titleCandidates,
      (result) => maxBy(
        result.titles,
        (title) => bestTitleScore(titleCandidates, title),
      )!,
    );
    return matches;
  }

  bool _hasExactTitle(
    animeheaven.AnimeResult result,
    List<String> titleCandidates,
  ) {
    final candidates = titleCandidates.map(normalizeTitle).toSet();
    return result.titles.map(normalizeTitle).any(candidates.contains);
  }

  /// Looks up alternative titles in AnimeHeaven's own result order, since score
  /// order is exactly what an inflated subset title distorts.
  Future<List<_SearchResults>> _withAlternativeTitles(
    List<_SearchResults> searchResults,
  ) async {
    final lookups = <String, Future<animeheaven.AnimeResult>>{};
    for (final (title: _, :results) in searchResults) {
      for (final result in results.take(_titleLookupsPerSearch)) {
        lookups.putIfAbsent(result.url, () => _fetchAlternativeTitles(result));
      }
    }
    final enriched = {
      for (final result in await Future.wait(lookups.values))
        result.url: result,
    };
    return [
      for (final (:title, :results) in searchResults)
        (
          title: title,
          results: [
            for (final result in results) enriched[result.url] ?? result,
          ],
        ),
    ];
  }

  Future<animeheaven.AnimeResult> _fetchAlternativeTitles(
    animeheaven.AnimeResult result,
  ) async {
    try {
      return await _source.fetchAlternativeTitles(result);
    } catch (e) {
      _log.warningWithMetadata(
        "AnimeHeaven alternative title lookup failed",
        metadata: {"url": result.url, "error": e.toString()},
      );
      return result;
    }
  }
}
