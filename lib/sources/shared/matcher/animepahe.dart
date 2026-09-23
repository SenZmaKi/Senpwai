import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/sources/animepahe.dart' as animepahe;
import 'package:senpwai/sources/shared/matcher/shared.dart';
import 'package:senpwai/sources/shared/shared.dart' as shared;

final _log = Logger("senpwai.sources.matcher.animepahe");

class AnimepaheMatcher {
  final animepahe.Source _source;

  AnimepaheMatcher({animepahe.Source? source})
    : _source = source ?? animepahe.Source.getInstance();

  Future<List<SourceMatch<animepahe.AnimeResult>>> match(
    AnilistAnimeBase<dynamic> anime,
  ) async {
    final titleCandidates = anime.title.toTitleCandidates();
    if (titleCandidates.isEmpty) return [];

    final allMatches = <SourceMatch<animepahe.AnimeResult>>[];
    final seenIds = <int>{};

    Future<({String title, List<animepahe.AnimeResult> results})> searchTitle(
      String title,
    ) async {
      try {
        final results = await _source.search(
          params: animepahe.SearchParams(term: title),
        );
        return (title: title, results: results.items);
      } on DioException catch (error) {
        _log.warningWithMetadata(
          "AnimePahe search failed for title candidate",
          metadata: {
            "title": title,
            "url": error.requestOptions.uri.toString(),
            "finalUrl": error.response?.realUri.toString(),
            "statusCode": error.response?.statusCode,
            "error": error.toString(),
          },
        );
        return (title: title, results: <animepahe.AnimeResult>[]);
      } catch (error) {
        _log.warningWithMetadata(
          "AnimePahe search failed for title candidate",
          metadata: {"title": title, "error": error.toString()},
        );
        return (title: title, results: <animepahe.AnimeResult>[]);
      }
    }

    final searchResults =
        <({String title, List<animepahe.AnimeResult> results})>[];
    var nextCandidate = 0;
    while (nextCandidate < titleCandidates.length) {
      final end = titleCandidates.length;
      searchResults.addAll(
        await Future.wait(
          titleCandidates.sublist(nextCandidate, end).map(searchTitle),
        ),
      );
      nextCandidate = end;
    }

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

    _sortMatches(allMatches, anime, titleCandidates);
    final topMatch = allMatches.firstOrNull;
    _log.fineWithMetadata(
      "AnimePahe matching complete",
      metadata: {
        "anilistId": anime.id,
        "anilistSeason": anime.season?.toDisplayLabel(),
        "anilistSeasonYear": anime.seasonYear,
        "matchCount": allMatches.length,
        "topTitle": topMatch?.result.title,
        "topSeason": topMatch?.result.season,
        "topYear": topMatch?.result.year,
        "topSession": topMatch?.result.session,
        "topScore": topMatch?.score,
      },
    );
    return allMatches;
  }

  void _sortMatches(
    List<SourceMatch<animepahe.AnimeResult>> matches,
    AnilistAnimeBase<dynamic> anime,
    List<String> titleCandidates,
  ) {
    final referenceTitleLength = titleCandidates
        .map((title) => title.length)
        .reduce((a, b) => a < b ? a : b);

    matches.sort((a, b) {
      // Metadata may rank plausible title matches, but must never promote a
      // candidate that failed the normal title-confidence threshold.
      final titleEligibility = _isTitleEligible(
        b,
      ).compareTo(_isTitleEligible(a));
      if (titleEligibility != 0) return titleEligibility;

      final yearCompatibility = _yearCompatibility(
        b.result,
        anime.seasonYear,
      ).compareTo(_yearCompatibility(a.result, anime.seasonYear));
      if (yearCompatibility != 0) return yearCompatibility;

      final seasonCompatibility =
          _seasonCompatibility(
            b.result,
            anime.season?.toDisplayLabel(),
          ).compareTo(
            _seasonCompatibility(a.result, anime.season?.toDisplayLabel()),
          );
      if (seasonCompatibility != 0) return seasonCompatibility;

      final titleScore = b.score.compareTo(a.score);
      if (titleScore != 0) return titleScore;

      final aLengthDifference = (a.result.title.length - referenceTitleLength)
          .abs();
      final bLengthDifference = (b.result.title.length - referenceTitleLength)
          .abs();
      return aLengthDifference.compareTo(bLengthDifference);
    });
  }

  int _isTitleEligible(SourceMatch<animepahe.AnimeResult> match) =>
      match.score >= shared.Constants.minMatchScore ? 1 : 0;

  int _yearCompatibility(animepahe.AnimeResult result, int? seasonYear) {
    if (seasonYear == null) return 0;
    return result.year == seasonYear ? 1 : -1;
  }

  int _seasonCompatibility(animepahe.AnimeResult result, String? seasonLabel) {
    if (seasonLabel == null) return 0;
    return result.season.toLowerCase() == seasonLabel.toLowerCase() ? 1 : -1;
  }
}
