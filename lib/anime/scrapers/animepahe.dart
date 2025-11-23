import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
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
}
