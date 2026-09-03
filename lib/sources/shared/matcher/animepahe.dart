import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/sources/animepahe.dart' as animepahe;
import 'package:senpwai/sources/shared/matcher/shared.dart';

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
            "requestCookieNames": _cookieNames(error.requestOptions),
            "requestHasUserAgent": _hasHeader(
              error.requestOptions,
              HttpHeaders.userAgentHeader,
            ),
            "responseSetCookieNames": _setCookieNames(error.response),
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
      final hasValidatedSession =
          GlobalDio.cfBypassInterceptor?.hasSessionForHost(
            animepahe.Constants.paheDomain,
          ) ==
          true;
      final end = hasValidatedSession
          ? titleCandidates.length
          : nextCandidate + 1;
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

  List<String> _cookieNames(RequestOptions options) {
    final cookieHeader = options.headers.entries
        .where((entry) => entry.key.toLowerCase() == HttpHeaders.cookieHeader)
        .map((entry) => entry.value.toString())
        .join('; ');
    return cookieHeader
        .split(';')
        .map((cookie) => cookie.trim())
        .where((cookie) => cookie.contains('='))
        .map((cookie) => cookie.substring(0, cookie.indexOf('=')))
        .toSet()
        .toList()
      ..sort();
  }

  bool _hasHeader(RequestOptions options, String name) => options.headers.keys
      .any((header) => header.toLowerCase() == name.toLowerCase());

  List<String> _setCookieNames(Response<dynamic>? response) {
    final headers = response?.headers[HttpHeaders.setCookieHeader] ?? const [];
    return headers
        .map((header) => header.split('=').first.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }
}
