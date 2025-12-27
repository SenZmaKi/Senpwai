import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anime/sources/shared/shared.dart';
import 'package:senpwai/anime/shared/net/net.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

final log = Logger("senpwai.anime.sources.animepahe");

class AnimeResult {
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

  AnimeResult({
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

  factory AnimeResult.fromJson(Map<String, dynamic> json) => AnimeResult(
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
    return "AnimeResult(id: $id, title: $title, type: $type, episodes: $episodes, status: $status, season: $season, year: $year, score: $score, poster: $poster, session: $session)";
  }
}

class Pagination<T> {
  final int currentPage;
  final int perPage;
  final int totalPages;
  final T items;
  final Future<Pagination<T>> Function()? fetchNextPage;

  Pagination({
    required this.currentPage,
    required this.totalPages,
    required this.items,
    required this.fetchNextPage,
    required this.perPage,
  });

  @override
  String toString() {
    return "Pagination(currentPage: $currentPage, totalPages: $totalPages, perPage: $perPage, items: $items, fetchNextPage: $fetchNextPage)";
  }
}

class Constants {
  static const paheDomain = "animepahe.si";
  static const paheHome = "https://$paheDomain";
  static const apiEntryPoint = "$paheHome/api?m=";
}

class SearchParams {
  final String term;
  final int page;

  SearchParams({required this.term, this.page = 1});

  @override
  String toString() {
    return "SearchParams(term: $term, page: $page)";
  }
}

class EpisodePageRange {
  final int startPageNum;
  final int endPageNum;
  final int total;
  final Map<String, dynamic> firstPageJson;

  EpisodePageRange({
    required this.startPageNum,
    required this.endPageNum,
    required this.total,
    required this.firstPageJson,
  });

  @override
  String toString() {
    return "EpisodePageRange(startPageNum: $startPageNum, endPageNum: $endPageNum, total: $total, firstPageJson: $firstPageJson)";
  }
}

class EpisodeSession {
  final String session;
  final int number;

  EpisodeSession({required this.session, required this.number});

  @override
  String toString() => "EpisodeSession(session: $session, number: $number)";
}

class Source {
  final Dio _apiDio;

  Source() : _apiDio = _buildApiDio();

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

  Future<Pagination<List<AnimeResult>>> search({
    required SearchParams params,
  }) async {
    log.info("Searching for $params");
    final term = params.term;
    final page = params.page;

    final response = await _apiDio.get(
      "search",
      queryParameters: {"q": term, "page": page},
    );
    final data = response.data;
    final results = data["data"] as List<dynamic>;
    final items = results.map((e) => AnimeResult.fromJson(e)).toList();
    final currentPage = page;
    final totalPages = data["total"] as int;
    final perPage = data["per_page"] as int;

    final nextPage = currentPage < totalPages
        ? () => search(
            params: SearchParams(term: term, page: page + 1),
          )
        : null;
    final pagination = Pagination(
      currentPage: currentPage,
      totalPages: totalPages,
      items: items,
      fetchNextPage: nextPage,
      perPage: perPage,
    );
    log.fine("Search results: $pagination");
    return pagination;
  }

  Future<Map<String, dynamic>> fetchEpisodeListPageJson({
    required String animeId,
    required int pageNum,
  }) async {
    final response = await _apiDio.get(
      "release",
      queryParameters: {"id": animeId, "sort": "episode_asc", "page": pageNum},
    );
    return response.data;
  }

  Future<EpisodePageRange> computeEpisodePageRange({
    required int startEpisode,
    required int endEpisode,
    required String animeId,
  }) async {
    final page = await fetchEpisodeListPageJson(animeId: animeId, pageNum: 1);
    final perPage = page["per_page"] as int;
    final startPageNum = (startEpisode / perPage).ceil();
    final endPageNum = (endEpisode / perPage).ceil();
    final total = (endPageNum - startPageNum) + 1;
    return EpisodePageRange(
      startPageNum: startPageNum,
      endPageNum: endPageNum,
      total: total,
      firstPageJson: page,
    );
  }

  Future<List<EpisodeSession>> fetchEpisodeSessions({
    required String animeId,
    required int pageNum,
    Map<String, dynamic>? pageJson,
  }) async {
    pageJson ??= await fetchEpisodeListPageJson(
      animeId: animeId,
      pageNum: pageNum,
    );
    final episodeSessionsJson = pageJson["data"] as List<dynamic>;
    final episodeSessions = episodeSessionsJson
        .map((e) => EpisodeSession(session: e["session"], number: e["episode"]))
        .toList();
    log.fine("Fetched episode sessions: $episodeSessions");
    return episodeSessions;
  }

  List<EpisodeSession> findEpisodeSessionsWithinRange({
    required String animeId,
    required int firstEpisode,
    required int startEpisode,
    required int endEpisode,
    required List<EpisodeSession> episodeSessions,
  }) {
    log.info(
      "Finding episode sessions within range ($animeId: animeId, $firstEpisode: firstEpisode, $startEpisode: startEpisode, $endEpisode: endEpisode, $episodeSessions: episodeSessions)",
    );
    int? startIdx;
    int? endIdx;

    for (var idx = 0; idx < episodeSessions.length; idx++) {
      // Sometimes for sequels animepahe continues the episode numbers from the last episode of the previous season
      // For instance  "Boku no Hero Academia 2nd Season" episode 1 is shown as episode 14
      // So we compute episode - (first_episode - 1) to get the real episode number e.g.,
      // 14 - (14 - 1) = 1
      // 15 - (14 - 1) = 2 and so on
      final episodeSession = episodeSessions[idx];
      final episode = episodeSession.number - (firstEpisode - 1);
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
    final withinRangeEpisodeSessions = episodeSessions
        .sublist(startIdx, endIdx + 1)
        .toList();
    log.fine(
      "Found episode sessions within range: $withinRangeEpisodeSessions",
    );
    return withinRangeEpisodeSessions;
  }
}
