import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:html/dom.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/log.dart';

final log = Logger("senpwai.anime.sources.tokyoinsider");
List<Element> parsePageResults(Document htmlPage) =>
    htmlPage.querySelectorAll("div.c_h2 > div > a, div.c_h2b > div > a");

class Constants {
  static const baseUrl = "https://www.tokyoinsider.com";
}

class AnimeResult {
  final String title;
  final String url;

  AnimeResult({required this.title, required this.url});

  @override
  String toString() {
    return "AnimeResult(title: $title, url: $url)";
  }
}

class AnimeResultAndScore {
  final AnimeResult result;
  final int score;

  AnimeResultAndScore({required this.result, required this.score});
}

class SearchParams {
  final String term;

  /// Minimum match score for the title to be considered a match
  final int minMatchScore;

  SearchParams({required this.term, this.minMatchScore = 70});

  @override
  String toString() {
    return "SearchParams(term: $term, minMatchScore: $minMatchScore)";
  }
}

class AnimeListCache {
  /// `~ 6000` entries as of today 23rd November 2025
  Set<AnimeResult>? _cache;
  final log = Logger("senpwai.anime.sources.tokyoinsider.animelistcache");
  final _expiryDuration = Duration(days: 1);
  bool _isInitialized = false;
  final Dio _dio;

  AnimeListCache({required Dio dio}) : _dio = dio;

  Future<void> _initializeCache() async {
    log.infoWithMetadata(
      !_isInitialized ? "Initializing cache" : "Refreshing cache",
      metadata: {},
    );
    final response = await _dio.get("${Constants.baseUrl}/anime/list");
    final htmlPage = parseHtml(response.data);
    final targetElements = parsePageResults(htmlPage);
    _cache = targetElements
        .map(
          (e) => AnimeResult(
            title: e.text.trim(),
            url: "${Constants.baseUrl}${e.attributes['href']}",
          ),
        )
        .toSet();
    log.fineWithMetadata(
      "Cache initialized",
      metadata: {"entries": _cache!.length},
    );
  }

  Future<void> _initialize() async {
    if (_isInitialized) {
      return;
    }
    await _initializeCache();
    Timer.periodic(_expiryDuration, (_) => _initializeCache());
    _isInitialized = true;
  }

  Future<List<AnimeResult>> search({required SearchParams params}) async {
    final term = params.term;
    final minMatchScore = params.minMatchScore;

    await _initialize();
    final resultsAndRatios = _cache!
        .map(
          (result) => AnimeResultAndScore(
            result: result,
            score: weightedRatio(term, result.title),
          ),
        )
        .where((e) => e.score >= minMatchScore)
        .toList();
    resultsAndRatios.sort((a, b) => b.score.compareTo(a.score));
    return resultsAndRatios.map((e) => e.result).toList();
  }
}

class EpisodePage {
  final String animeTitle;
  final String title;
  final String url;

  EpisodePage({
    required this.animeTitle,
    required this.title,
    required this.url,
  });

  @override
  String toString() =>
      "EpisodePage(animeTitle: $animeTitle, title: $title, url: $url)";
}

class EpisodeDownloadLink {
  final String animeTitle;
  final String episodeTitle;
  final String filename;
  final String url;

  EpisodeDownloadLink({
    required this.animeTitle,
    required this.filename,
    required this.url,
    required this.episodeTitle,
  });

  @override
  String toString() =>
      "EpisodeDownloadLink(animeTitle: $animeTitle, episodeTitle: $episodeTitle, filename: $filename, url: $url)";
}

class Source {
  final Dio _dio;
  late final AnimeListCache _animeListCache;

  Source() : _dio = defaultDio() {
    _animeListCache = AnimeListCache(dio: _dio);
  }

  Future<List<AnimeResult>> search({required SearchParams params}) async {
    log.infoWithMetadata("Searching", metadata: {"params": params});
    final results = await _animeListCache.search(params: params);
    log.fineWithMetadata(
      "Searched",
      metadata: {"params": params, "results": results},
    );
    return results;
  }

  Future<List<EpisodePage>> fetchEpisodePages({
    required String animeUrl,
    required String animeTitle,
  }) async {
    log.infoWithMetadata(
      "Fetching episode pages",
      metadata: {"animeTitle": animeTitle, "animeUrl": animeUrl},
    );
    final response = await _dio.get(animeUrl);
    final htmlPage = parseHtml(response.data);
    final targetElements = parsePageResults(htmlPage);
    final episodePages = targetElements.map((el) {
      final path = el.attributes["href"];
      if (path == null) {
        throw SourceException(
          message: "Could not find episode url",
          metadata: {"animeUrl": animeUrl},
        );
      }
      final url = "${Constants.baseUrl}$path";
      final title = el.text.trim();
      return EpisodePage(animeTitle: animeTitle, title: title, url: url);
    }).toList();
    log.fineWithMetadata(
      "Fetched episode pages",
      metadata: {"animeTitle": animeTitle, "episodePages": episodePages},
    );
    return episodePages;
  }

  Future<List<EpisodeDownloadLink>> fetchEpisodeDownloadLinks({
    required EpisodePage episodePage,
  }) async {
    log.infoWithMetadata(
      "Fetching episode download links",
      metadata: {"episodePage": episodePage},
    );
    final response = await _dio.get(episodePage.url);
    final htmlPage = parseHtml(response.data);
    final targetElements = parsePageResults(htmlPage);
    final episodeDownloadLinks = targetElements.map((el) {
      final path = el.attributes["href"];
      if (path == null) {
        throw SourceException(
          message: "Failed to find episode url",
          metadata: {"episodePage": episodePage},
        );
      }
      final filename = el.text.trim();
      final url = "${Constants.baseUrl}$path";
      final animeTitle = episodePage.animeTitle;
      final episodeTitle = episodePage.title;
      return EpisodeDownloadLink(
        filename: filename,
        url: url,
        animeTitle: animeTitle,
        episodeTitle: episodeTitle,
      );
    }).toList();
    log.fineWithMetadata(
      "Fetched episode download links",
      metadata: {
        "episodePage": episodePage,
        "episodeDownloadLinks": episodeDownloadLinks,
      },
    );
    return episodeDownloadLinks;
  }
}
