import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anime/scrapers/shared/shared.dart';
import 'package:senpwai/anime/shared/net/net.dart';

class Constants {
  static const baseUrl = "https://www.tokyoinsider.com";
}

class SearchResult {
  final String title;
  final String url;

  SearchResult({required this.title, required this.url});

  @override
  String toString() {
    return "SearchResult(title: $title, url: $url)";
  }
}

class ResultAndScore {
  final SearchResult result;
  final int score;

  ResultAndScore({required this.result, required this.score});
}

class SearchOptions {
  final String keyword;

  SearchOptions({required this.keyword});
}

class EpisodeUrl {}

class AnimeListCache {
  /// `~ 6000` entries as of today 23rd November 2025
  Set<SearchResult>? _cache;
  final log = Logger("senpwai.anime.scrapers.tokyoinsider.cache");
  final _expiryDuration = Duration(days: 1);
  bool _isInitialized = false;
  final Dio _dio;

  AnimeListCache({required Dio dio}) : _dio = dio;

  Future<void> _initializeCache() async {
    log.info(!_isInitialized ? "Initializing cache" : "Refreshing cache");
    final response = await _dio.get("${Constants.baseUrl}/anime/list");
    final htmlPage = parseHtml(response.data);
    final targetElements = htmlPage.querySelectorAll(
      "div.c_h2 > a, div.c_h2b > a",
    );
    _cache = targetElements
        .map(
          (e) => SearchResult(
            title: e.text.trim(),
            url: "${Constants.baseUrl}${e.attributes['href']}",
          ),
        )
        .toSet();
    log.fine("Cache initialized with ${_cache!.length} entries");
  }

  Future<void> _initialize() async {
    if (_isInitialized) {
      return;
    }
    await _initializeCache();
    Timer.periodic(_expiryDuration, (_) => _initializeCache());
    _isInitialized = true;
  }

  Future<List<SearchResult>> search({
    required String keyword,
    int minScore = 70,
  }) async {
    await _initialize();
    final resultsAndRatios = _cache!
        .map(
          (result) => ResultAndScore(
            result: result,
            score: weightedRatio(keyword, result.title),
          ),
        )
        .where((e) => e.score >= minScore)
        .toList();
    resultsAndRatios.sort((a, b) => b.score.compareTo(a.score));
    return resultsAndRatios.map((e) => e.result).toList();
  }
}

class Episode {
  final String title;
  final String url;

  Episode({required this.title, required this.url});

  @override
  String toString() => "Episode(title=$title, url=$url)";
}

class TokyoInsiderScraper {
  final Dio _dio;
  final log = Logger("senpwai.anime.scrapers.tokyoinsider");
  late final AnimeListCache _animeListCache;

  TokyoInsiderScraper() : _dio = defaultDio() {
    _animeListCache = AnimeListCache(dio: _dio);
  }

  Future<List<SearchResult>> search({required SearchOptions options}) async {
    final keyword = options.keyword;
    return _animeListCache.search(keyword: keyword);
  }

  Future<List<Episode>> getEpisodes({
    required String animeUrl,
  }) async {
    final response = await _dio.get(animeUrl);
    final htmlPage = parseHtml(response.data);
    final targetElements = htmlPage.querySelectorAll(
      "div.c_h2 > div > a, div.c_h2b > div > a",
    );
    final episode = targetElements.map((el) {
      final path = el.attributes["href"];
      if (path == null) {
        throw ScrapingException(
          "Could not find episode url for animeUrl=$animeUrl",
        );
      }
      final url = "${Constants.baseUrl}$path";
      final title = el.text.trim();
      return Episode(title: title, url: url);
    });
    return episode.toList();
  }
}
