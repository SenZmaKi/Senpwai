import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:html/dom.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anime/scrapers/shared/shared.dart';
import 'package:senpwai/anime/shared/net/net.dart';

List<Element> parsePageResults(Document htmlPage) =>
    htmlPage.querySelectorAll("div.c_h2 > div > a, div.c_h2b > div > a");

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
    final targetElements = parsePageResults(htmlPage);
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

class EpisodePage {
  final String episodeTitle;
  final String url;

  EpisodePage({required this.episodeTitle, required this.url});

  @override
  String toString() => "Episode(title=$episodeTitle, url=$url)";
}

class EpisodeDownloadLinks {
  final String filename;
  final String url;

  EpisodeDownloadLinks({required this.filename, required this.url});

  @override
  String toString() => "Episode(filename=$filename, url=$url)";
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

  Future<List<EpisodePage>> getEpisodePages({required String animeUrl}) async {
    final response = await _dio.get(animeUrl);
    final htmlPage = parseHtml(response.data);
    final targetElements = parsePageResults(htmlPage);
    final episodePages = targetElements.map((el) {
      final path = el.attributes["href"];
      if (path == null) {
        throw ScrapingException(
          "Could not find episode url for animeUrl=$animeUrl",
        );
      }
      final url = "${Constants.baseUrl}$path";
      final episodeTitle = el.text.trim();
      return EpisodePage(episodeTitle: episodeTitle, url: url);
    });
    return episodePages.toList();
  }

  Future<List<EpisodeDownloadLinks>> getEpisodeDownloadLinks({
    required EpisodePage episodePage,
  }) async {
    final response = await _dio.get(episodePage.url);
    final htmlPage = parseHtml(response.data);
    final targetElements = parsePageResults(htmlPage);
    final episodeDownloadLinks = targetElements.map((el) {
      final path = el.attributes["href"];
      if (path == null) {
        throw ScrapingException("Failed to find episode url for $episodePage");
      }
      final filename = el.text.trim();
      final url = "${Constants.baseUrl}$path";
      return EpisodeDownloadLinks(filename: filename, url: url);
    }).toList();
    return episodeDownloadLinks;
  }
}
