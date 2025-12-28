import 'dart:math';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:html/dom.dart' as html;
import 'package:senpwai/shared/shared.dart' as shared;

final log = Logger("senpwai.anime.sources.animepahe");

class DownloadLinkMatchException implements Exception {
  final String message;

  DownloadLinkMatchException(this.message);

  @override
  String toString() => 'DownloadLinkMatchException: $message';
}

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
  static const englishSuffix = "eng";

  static final estimatedSizeRegex = RegExp(r"\b(\d+)MB\b");
  static final kwikLinkRegex = RegExp(r"""https?://kwik\.cx/f/([^\"']+)""");
  static final kwikParamRegex = RegExp(
    r"""\(\"(\w+)\",\d+,\"(\w+)\",(\d+),(\d+),(\d+)\)""",
  );
  static final kwikCharMap =
      "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+/";
  static final kwikCharMapBase = 10;
  static final kwikCharMapDigits = kwikCharMap.substring(0, kwikCharMapBase);

  static String buildEpisodePageUrl(
    String animeSession,
    String episodeSession,
  ) => "${Constants.paheHome}/play/$animeSession/$episodeSession";
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

class DownloadLink {
  final String animeTitle;
  final int episodeNumber;
  final String filename;
  final String url;
  final int estimatedSizeBytes;
  final Language audioLanguage;
  final Resolution resolution;

  DownloadLink({
    required this.animeTitle,
    required this.episodeNumber,
    required this.filename,
    required this.url,
    required this.estimatedSizeBytes,
    required this.audioLanguage,
    required this.resolution,
  });

  @override
  String toString() {
    return "DownloadLink(animeTItle: $animeTitle, episodeNumber: $episodeNumber, filename: $filename, url: $url, estimatedSizeBytes: $estimatedSizeBytes, audioLanguage: $audioLanguage, resolution: $resolution)";
  }
}

class DirectDownloadLink {
  final String animeTitle;
  final int episodeNumber;
  final String filename;
  final String url;

  DirectDownloadLink({
    required this.animeTitle,
    required this.episodeNumber,
    required this.filename,
    required this.url,
  });
  @override
  String toString() {
    return "DirectDownloadLink(animeTitle: $animeTitle, episodeNumber: $episodeNumber, filename: $filename, url: $url)";
  }
}

class Source {
  final Dio _dio;

  Source() : _dio = _buildDio();

  static Dio _buildDio() {
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

    final response = await _dio.get(
      "search",
      queryParameters: {"q": term, "page": page},
    );
    final data = response.data;
    final results = data["data"] as List<dynamic>;
    final items = results.map((e) => AnimeResult.fromJson(e)).toList();
    final currentPage = page;
    final totalPages = data["total"] as int;
    final perPage = data["per_page"] as int;

    final fetchNextpage = currentPage < totalPages
        ? () => search(
            params: SearchParams(term: term, page: page + 1),
          )
        : null;
    final pagination = Pagination(
      currentPage: currentPage,
      totalPages: totalPages,
      items: items,
      fetchNextPage: fetchNextpage,
      perPage: perPage,
    );
    log.fine("Search results: $pagination");
    return pagination;
  }

  Future<Map<String, dynamic>> fetchEpisodeListPageJson({
    required String animeSession,
    required int pageNum,
  }) async {
    final response = await _dio.get(
      "release",
      queryParameters: {
        "id": animeSession,
        "sort": "episode_asc",
        "page": pageNum,
      },
    );
    return response.data;
  }

  Future<EpisodePageRange> computeEpisodePageRange({
    required int startEpisode,
    required int endEpisode,
    required String animeSession,
  }) async {
    final page = await fetchEpisodeListPageJson(
      animeSession: animeSession,
      pageNum: 1,
    );
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
    required String animeSession,
    required int pageNum,
    Map<String, dynamic>? pageJson,
  }) async {
    pageJson ??= await fetchEpisodeListPageJson(
      animeSession: animeSession,
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
    required String animeSession,
    required int firstEpisode,
    required int startEpisode,
    required int endEpisode,
    required List<EpisodeSession> episodeSessions,
  }) {
    log.info(
      "Finding episode sessions within range ($animeSession: animeSession, $firstEpisode: firstEpisode, $startEpisode: startEpisode, $endEpisode: endEpisode, $episodeSessions: episodeSessions)",
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
      throw SourceException(
        message: "Could not find ${startIdx == null ? "start" : "end"} episode",
        metadata: {
          "animeSession": animeSession,
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

  int? _parseEstimatedSizeBytes(String filename) {
    final match = Constants.estimatedSizeRegex.firstMatch(filename);
    if (match == null) {
      return null;
    }
    final size = match.group(1);
    if (size == null) {
      return null;
    }
    final sizeMegabytes = int.parse(size);
    final sizeBytes = sizeMegabytes * shared.Constants.megaByte;
    return sizeBytes;
  }

  DownloadLink _parseDownloadLink({
    required html.Element element,
    required String animeTitle,
    required int episodeNumber,
  }) {
    final url = element.attributes["href"];
    if (url == null) {
      throw SourceException(
        message: "Failed to find direct download link",
        metadata: {"url": url, "element": element},
      );
    }
    final filename = element.text.trim();
    final resolution = parseResolution(filename);
    if (resolution == null) {
      throw SourceException(
        message: "Failed to parse resolution",
        metadata: {"filename": filename, "element": element},
      );
    }
    final audioLanguage = _parseAudioLanguage(filename);
    final estimatedSizeBytes = _parseEstimatedSizeBytes(filename);
    if (estimatedSizeBytes == null) {
      throw SourceException(
        message: "Failed to find estimated size bytes",
        metadata: {"filename": filename, "element": element},
      );
    }
    return DownloadLink(
      animeTitle: animeTitle,
      episodeNumber: episodeNumber,
      filename: filename,
      url: url,
      resolution: resolution,
      audioLanguage: audioLanguage,
      estimatedSizeBytes: estimatedSizeBytes,
    );
  }

  Language _parseAudioLanguage(String downloadFileName) =>
      downloadFileName.endsWith(Constants.englishSuffix)
      ? Language.english
      : Language.japanese;

  DownloadLink findBestDownloadLinkMatch({
    required String animeTitle,
    required int episodeNumber,
    required Resolution resolution,
    required Language audioLanguage,
    required List<DownloadLink> downloadLinks,
  }) {
    log.info(
      "Finding best download link match: (animeTitle: $animeTitle, episodeNumber: $episodeNumber, resolution: $resolution, audioLanguage: $audioLanguage, downloadLinks: $downloadLinks)",
    );

    final audioLanguageMatches = downloadLinks
        .where((link) => link.audioLanguage == audioLanguage)
        .toSet();
    if (audioLanguageMatches.isEmpty) {
      throw DownloadLinkMatchException(
        'No $audioLanguage download links found for "$animeTitle" episode $episodeNumber',
      );
    }

    final resolutionMatches = downloadLinks
        .where((link) => link.resolution == resolution)
        .toSet();
    if (resolutionMatches.isEmpty) {
      throw DownloadLinkMatchException(
        'No $resolution download links found for "$animeTitle" episode $episodeNumber',
      );
    }

    final bestMatch = audioLanguageMatches
        .intersection(resolutionMatches)
        .first;
    log.fine("Found best download link match: $bestMatch");
    return bestMatch;
  }

  Future<List<DownloadLink>> fetchDownloadLinks({
    required String animeTitle,
    required String animeSession,
    required EpisodeSession episodeSession,
  }) async {
    log.info(
      "Fetching download links for (animeTitle: $animeTitle, animeSession: $animeSession, episodeSession: $episodeSession)",
    );
    final episodePageUrl = Constants.buildEpisodePageUrl(
      animeSession,
      episodeSession.session,
    );
    final response = await _dio.get(episodePageUrl);
    final htmlPage = parseHtml(response.data);
    final downloadAElements = htmlPage.querySelectorAll(
      'a.dropdown-item[target="_blank"]',
    );
    final episodeNumber = episodeSession.number;
    final downloadLinks = downloadAElements
        .map(
          (element) => _parseDownloadLink(
            element: element,
            animeTitle: animeTitle,
            episodeNumber: episodeNumber,
          ),
        )
        .toList();
    log.fine("Fetched download links: $downloadLinks");
    return downloadLinks;
  }

  int _getCharCode(String content, int s1) {
    int j = 0;
    final reversedContent = content.split('').reversed.toList();
    for (int index = 0; index < reversedContent.length; index++) {
      final c = int.tryParse(reversedContent[index]) ?? 0;
      j += (c * pow(s1, index).toInt());
    }
    String k = "";
    while (j > 0) {
      k = Constants.kwikCharMapDigits[j % Constants.kwikCharMapBase] + k;
      j = (j - (j % Constants.kwikCharMapBase)) ~/ Constants.kwikCharMapBase;
    }
    return k.isNotEmpty ? int.parse(k) : 0;
  }

  String _extractAndDecryptKwikForm(String htmlPageText) {
    final match = Constants.kwikParamRegex.firstMatch(htmlPageText);
    if (match == null) {
      throw SourceException(
        message: "No match found for kwik param",
        metadata: {"htmlPageText": htmlPageText},
      );
    }

    final fullKey = match.group(1)!;
    final key = match.group(2)!;
    final v1 = int.parse(match.group(3)!);
    final v2 = int.parse(match.group(4)!);

    String r = "";
    int i = 0;
    while (i < fullKey.length) {
      String s = "";
      while (fullKey[i] != key[v2]) {
        s += fullKey[i];
        i++;
      }
      for (int idx = 0; idx < key.length; idx++) {
        s = s.replaceAll(key[idx], idx.toString());
      }
      r += String.fromCharCode(_getCharCode(s, v2) - v1);
      i++;
    }
    return r;
  }

  (String postUrl, String token) _extractPostUrlAndToken(String formHtml) {
    final formDoc = parseHtml(formHtml);
    final formElement = formDoc.querySelector('form');
    if (formElement == null) {
      throw SourceException(
        message: "No form element found in decrypted content",
        metadata: {"formHtml": formHtml},
      );
    }

    final postUrl = formElement.attributes['action'];
    if (postUrl == null) {
      throw SourceException(
        message: "No action attribute found in form element",
        metadata: {"formHtml": formHtml},
      );
    }

    final inputElement = formDoc.querySelector('input');
    if (inputElement == null) {
      throw SourceException(
        message: "No input element found in decrypted content",
        metadata: {"formHtml": formHtml},
      );
    }

    final token = inputElement.attributes['value'];
    if (token == null) {
      throw SourceException(
        message: "No value attribute found in input element",
        metadata: {"formHtml": formHtml},
      );
    }

    return (postUrl, token);
  }

  Future<DirectDownloadLink> _fetchDirectDownloadLinkFromKwikPage({
    required String kwikPageLink,
    required DownloadLink downloadLink,
  }) async {
    log.info(
      "Fetching direct download link from kwik page link (downloadLink: $downloadLink, kwikPageLink: $kwikPageLink)",
    );

    final response = await _dio.get<String>(kwikPageLink);
    final htmlPageText = response.data;
    if (htmlPageText == null) {
      throw SourceException(
        message: "Received empty response from kwik page",
        metadata: {"kwikPageLink": kwikPageLink},
      );
    }

    log.info(
      "Extracting and decrypting kwik form (kwikPageLink: $kwikPageLink)",
    );
    final formHtml = _extractAndDecryptKwikForm(htmlPageText);
    log.fine(
      "Extracted and decrypted kwik form (kwikPageLink: $kwikPageLink): $formHtml",
    );
    log.info(
      "Extracting post url and token from kwik form (kwikPageLink: $kwikPageLink)",
    );
    final (postUrl, token) = _extractPostUrlAndToken(formHtml);
    log.fine(
      "Extracted post url and token from kwik form (kwikPageLink: $kwikPageLink): (postUrl: $postUrl, token: $token)",
    );

    final postResponse = await _dio.post<String>(
      postUrl,
      data: {'_token': token},
      options: Options(
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
        headers: {'Referer': kwikPageLink},
      ),
    );

    final directDownloadUrl = postResponse.headers.value('location');
    if (directDownloadUrl == null) {
      throw SourceException(
        message: "No Location header found in post response",
        metadata: {"postUrl": postUrl, "kwikPageLink": kwikPageLink},
      );
    }

    final directDownloadLink = DirectDownloadLink(
      animeTitle: downloadLink.animeTitle,
      episodeNumber: downloadLink.episodeNumber,
      filename: downloadLink.filename,
      url: directDownloadUrl,
    );

    log.fine(
      "Fetched direct download link from kwik page link (downloadLink: $downloadLink, kwikPageLink: $kwikPageLink): $directDownloadLink",
    );
    return directDownloadLink;
  }

  Future<DirectDownloadLink> fetchDirectDownloadLink({
    required DownloadLink downloadLink,
  }) async {
    log.info("Fetching direct download link (downloadLink: $downloadLink)");
    final response = await _dio.get<String>(downloadLink.url);
    final htmlPageText = response.data;
    if (htmlPageText == null) {
      throw SourceException(
        message: "Received empty response from pahewin",
        metadata: {
          "downloadLink": downloadLink,
          "htmlPageText": htmlPageText,
          "response": response,
        },
      );
    }
    final kwikMatch = Constants.kwikLinkRegex.firstMatch(htmlPageText);
    if (kwikMatch == null) {
      throw SourceException(
        message: "No match found for kwik page link",
        metadata: {"downloadLink": downloadLink, "htmlPageText": htmlPageText},
      );
    }
    final kwikPageLink = kwikMatch.group(0)!;
    final directDownloadLink = await _fetchDirectDownloadLinkFromKwikPage(
      downloadLink: downloadLink,
      kwikPageLink: kwikPageLink,
    );
    log.fine(
      "Fetched direct download link downloadLink: $downloadLink, kwikPageLink: $kwikPageLink): $directDownloadLink",
    );
    return directDownloadLink;
  }
}
