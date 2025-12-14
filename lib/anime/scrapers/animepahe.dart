import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anime/scrapers/shared/shared.dart';
import 'package:senpwai/anime/shared/net/net.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

class SearchResult {
  int id;
  String title;
  String type;
  int episodes;
  String status;
  String season;
  int year;
  double score;
  String poster;
  String session;

  SearchResult({
    required this.id,
    required this.title,
    required this.type,
    required this.episodes,
    required this.status,
    required this.season,
    required this.year,
    required this.score,
    required this.poster,
    required this.session,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
    id: json["id"],
    title: json["title"],
    type: json["type"],
    episodes: json["episodes"],
    status: json["status"],
    season: json["season"],
    year: json["year"],
    score: json["score"],
    poster: json["poster"],
    session: json["session"],
  );

  @override
  String toString() {
    return "SearchResult(id: $id, title: $title, type: $type, episodes: $episodes, status: $status, season: $season, year: $year, score: $score, poster: $poster, session: $session)";
  }
}

class Pagination<T> {
  final int currentPage;
  final int perPage;
  final int totalPages;
  final T items;
  final Future<Pagination<T>> Function()? nextPage;

  Pagination({
    required this.currentPage,
    required this.totalPages,
    required this.items,
    required this.nextPage,
    required this.perPage,
  });

  @override
  String toString() {
    return "Pagination(currentPage: $currentPage, totalPages: $totalPages, perPage: $perPage, items: $items, nextPage: $nextPage)";
  }
}

class Constants {
  static const paheDomain = "animepahe.si";
  static const paheHome = "https://$paheDomain";
  static const apiEntryPoint = "$paheHome/api?m=";
}

class SearchOptions {
  final String keyword;
  final int page;

  SearchOptions({required this.keyword, this.page = 1});
}

class EpisodePagesInfo {
  final int startPageNum;
  final int endPageNum;
  final int total;
  final Map<String, dynamic> firstPageJson;

  EpisodePagesInfo({
    required this.startPageNum,
    required this.endPageNum,
    required this.total,
    required this.firstPageJson,
  });

  @override
  String toString() {
    return "EpisodePagesInfo(startPageNum: $startPageNum, endPageNum: $endPageNum, total: $total, firstPageJson: $firstPageJson)";
  }
}

class EpisodePage {
  final String url;
  final int episode;

  EpisodePage({required this.url, required this.episode});
}

class EpisodeSession {
  final String session;
  final int episodeNumber;

  EpisodeSession({required this.session, required this.episodeNumber});
}

class AnimepaheScraper {
  final Dio _apiDio;
  final log = Logger("senpwai.anime.scrapers.animepahe");

  AnimepaheScraper() : _apiDio = _buildApiDio();

  static Dio _buildApiDio() {
    final uri = Uri.parse(Constants.paheHome);

    /*
    For some reason these cookies just need to be set, they don't even need to be valid
    Also as I am writing this only only __ddg2_ is necessary
    */
    final cookies = [Cookie("__ddg1_", ""), Cookie("__ddg2_", "")];
    final cookieJar = CookieJar();
    cookieJar.saveFromResponse(uri, cookies);
    final apiDio = defaultDio()..options.baseUrl = Constants.apiEntryPoint;
    apiDio.interceptors.add(CookieManager(cookieJar));
    return apiDio;
  }

  Future<Pagination<List<SearchResult>>> search({
    required SearchOptions options,
  }) async {
    final keyword = options.keyword;
    final page = options.page;

    log.info("Searching for (keyword: $keyword, page: $page)");

    final response = await _apiDio.get(
      "search",
      queryParameters: {"q": keyword, "page": page},
    );
    final data = response.data;
    final results = data["data"] as List<dynamic>;
    final items = results.map((e) => SearchResult.fromJson(e)).toList();
    final currentPage = page;
    final totalPages = data["total"] as int;
    final perPage = data["per_page"] as int;

    final nextPage = currentPage < totalPages
        ? () => search(
            options: SearchOptions(keyword: keyword, page: page + 1),
          )
        : null;
    final pagination = Pagination(
      currentPage: currentPage,
      totalPages: totalPages,
      items: items,
      nextPage: nextPage,
      perPage: perPage,
    );
    log.fine("Search results: $pagination");
    return pagination;
  }

  Future<Map<String, dynamic>> getEpisodeListPagesJson({
    required String animeId,
    required int pageNum,
  }) async {
    final response = await _apiDio.get(
      "release",
      queryParameters: {"id": animeId, "sort": "episode_asc", "page": pageNum},
    );
    return response.data;
  }

  Future<EpisodePagesInfo> calculateEpisodeListPagesInfo({
    required int startEpisode,
    required int endEpisode,
    required String animeId,
  }) async {
    final page = await getEpisodeListPagesJson(animeId: animeId, pageNum: 1);
    final perPage = page["per_page"] as int;
    final startPageNum = (startEpisode / perPage).ceil();
    final endPageNum = (endEpisode / perPage).ceil();
    final total = (endPageNum - startPageNum) + 1;
    return EpisodePagesInfo(
      startPageNum: startPageNum,
      endPageNum: endPageNum,
      total: total,
      firstPageJson: page,
    );
  }

  Future<List<EpisodeSession>> getEpisodeListPageSessions({
    required String animeId,
    required int pageNum,
    Map<String, dynamic>? pageJson,
  }) async {
    pageJson ??= await getEpisodeListPagesJson(
      animeId: animeId,
      pageNum: pageNum,
    );
    final episodes = pageJson["data"] as List<dynamic>;
    return episodes
        .map(
          (e) => EpisodeSession(
            session: e["session"],
            episodeNumber: e["episode"],
          ),
        )
        .toList();
  }

  List<EpisodePage> generateEpisodePages({
    required String animeId,
    required int firstEpisode,
    required int startEpisode,
    required int endEpisode,
    required List<EpisodeSession> episodeSessions,
  }) {
    int? startIdx;
    int? endIdx;

    for (var idx = 0; idx < episodeSessions.length; idx++) {
      // Sometimes for sequels animepahe continues the episode numbers from the last episode of the previous season
      // For instance  "Boku no Hero Academia 2nd Season" episode 1 is shown as episode 14
      // So we compute episode - (first_episode - 1) to get the real episode number e.g.,
      // 14 - (14 - 1) = 1
      // 15 - (14 - 1) = 2 and so on
      final episodeSession = episodeSessions[idx];
      final episode = episodeSession.episodeNumber - (firstEpisode - 1);
      if (episode == startEpisode) {
        startIdx = idx;
      }
      if (episode == endEpisode) {
        endIdx = idx;
        break;
      }
    }
    if (startIdx == null || endIdx == null) {
      throw ScrapingException(
        message: "Could not find ${startIdx == null ? "start" : "end"} episode",
        metadata: {
          "animeId": animeId,
          "startEpisode": startEpisode,
          "endEpisode": endEpisode,
          "episodeSessions": episodeSessions,
        },
      );
    }
    return episodeSessions
        .sublist(startIdx, endIdx + 1)
        .map((e) => EpisodePage(url: e.session, episode: e.episodeNumber))
        .toList();
  }
}
