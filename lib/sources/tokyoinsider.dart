import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:collection/collection.dart';
import 'package:senpwai/sources/shared/fuzzy.dart';
import 'package:html/dom.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anitomy/anitomy.dart' as anitomy_parser;
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/source_directory/source_directory.dart';
import 'package:senpwai/shared/log.dart';

final log = Logger("senpwai.anime.sources.tokyoinsider");
List<Element> parsePageResults(Document htmlPage) =>
    htmlPage.querySelectorAll("div.c_h2 > div > a, div.c_h2b > div > a");
List<Element> _parseEncodedDownloadRows(Document htmlPage) =>
    htmlPage.querySelectorAll('div.episode span.download-link[data-a][data-b]');
List<Element> _parseEncodedFileRows(Document htmlPage) =>
    htmlPage.querySelectorAll(
      'div.c_h2 > div > span.dlk[data-a][data-b], '
      'div.c_h2b > div > span.dlk[data-a][data-b]',
    );

class Constants {
  static String get baseUrl => SourceDirectory.instance.tokyoInsider.baseUrl;
}

String _resolveUrl(String href) =>
    Uri.parse(Constants.baseUrl).resolve(href).toString();

void _logHtmlResponseDiagnostics({
  required String operation,
  required Response<dynamic> response,
  required Document htmlPage,
  required List<Element> targetElements,
  required Map<String, dynamic> context,
}) {
  final body = response.data is String ? response.data as String : null;
  final bodyLower = body?.toLowerCase() ?? '';
  final documentTitle = htmlPage.querySelector('title')?.text.trim();
  final challengeIndicators = <String>[
    if ((documentTitle ?? '').toLowerCase().contains('just a moment'))
      'just-a-moment-title',
    if (bodyLower.contains('performing security verification'))
      'security-verification-text',
    if (bodyLower.contains('enable javascript and cookies'))
      'javascript-cookies-required',
    if (bodyLower.contains('challenges.cloudflare.com'))
      'cloudflare-challenges-host',
    if (bodyLower.contains('cdn-cgi/challenge-platform'))
      'cloudflare-challenge-platform',
    if (bodyLower.contains('cf_chl_') || bodyLower.contains('cf-chl-'))
      'cloudflare-challenge-marker',
  ];
  final episodeHrefCount = htmlPage
      .querySelectorAll('a[href*="/episode/"]')
      .length;
  final encodedDownloadLinkCount = htmlPage
      .querySelectorAll('div.episode span.download-link[data-a][data-b]')
      .length;
  final encodedFileLinkCount = htmlPage
      .querySelectorAll('span.dlk[data-a][data-b]')
      .length;
  final isUnexpected = targetElements.isEmpty || challengeIndicators.isNotEmpty;
  final metadata = <String, dynamic>{
    ...context,
    'operation': operation,
    'requestUrl': response.requestOptions.uri.toString(),
    'responseUrl': response.realUri.toString(),
    'statusCode': response.statusCode,
    'contentType': response.headers.value(Headers.contentTypeHeader),
    'server': response.headers.value('server'),
    'cfMitigated': response.headers.value('cf-mitigated'),
    'cfRay': response.headers.value('cf-ray'),
    'fromNetwork': response.extra[extraFromNetworkKey],
    'bodyLength': body?.length,
    'documentTitle': documentTitle,
    'allAnchorCount': htmlPage.querySelectorAll('a').length,
    'episodeHrefCount': episodeHrefCount,
    'encodedDownloadLinkCount': encodedDownloadLinkCount,
    'encodedFileLinkCount': encodedFileLinkCount,
    'targetElementCount': targetElements.length,
    'selectorMismatch':
        targetElements.isEmpty &&
        (episodeHrefCount > 0 ||
            encodedDownloadLinkCount > 0 ||
            encodedFileLinkCount > 0),
    'challengeIndicators': challengeIndicators,
  };

  if (isUnexpected) {
    log.warningWithMetadata(
      'TokyoInsider returned unexpected HTML',
      metadata: metadata,
    );
    return;
  }
  log.fineWithMetadata(
    'TokyoInsider HTML response diagnostics',
    metadata: metadata,
  );
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
    final targetElements = htmlPage.querySelectorAll(
      "div.c_h2 > a, div.c_h2b > a",
    );
    _cache = targetElements
        .map(
          (e) => AnimeResult(
            title: e.text.trim(),
            url: _resolveUrl(e.attributes['href']!),
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
            score: titleSimilarity(term, result.title),
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
  final int episodeNumber;

  EpisodePage({
    required this.animeTitle,
    required this.title,
    required this.url,
    required this.episodeNumber,
  });

  @override
  String toString() =>
      "EpisodePage(animeTitle: $animeTitle, title: $title, url: $url, episodeNumber: $episodeNumber)";
}

class EpisodeDownloadLink {
  final String animeTitle;
  final String episodeTitle;
  final int episodeNumber;
  final String filename;
  final String url;
  final Resolution? resolution;
  final Language? language;

  EpisodeDownloadLink({
    required this.animeTitle,
    required this.episodeNumber,
    required this.filename,
    required this.url,
    required this.episodeTitle,
    required this.resolution,
    required this.language,
  });

  @override
  String toString() =>
      "EpisodeDownloadLink(animeTitle: $animeTitle, episodeTitle: $episodeTitle, episodeNumber: $episodeNumber, filename: $filename, url: $url, resolution: $resolution, language: $language)";
}

List<EpisodePage> _parseLegacyEpisodePages({
  required List<Element> elements,
  required String animeTitle,
  required String animeUrl,
}) {
  return elements.mapIndexed((index, element) {
    final path = element.attributes["href"];
    if (path == null) {
      throw SourceException(
        message: "Could not find episode url",
        metadata: {"animeUrl": animeUrl},
      );
    }
    final title = element.text.trim();
    return EpisodePage(
      animeTitle: animeTitle,
      title: title,
      url: _resolveUrl(path),
      episodeNumber: _parseEpisodeNumber(title) ?? index + 1,
    );
  }).toList();
}

List<EpisodePage> _parseEncodedEpisodePages({
  required Document htmlPage,
  required List<Element> elements,
  required String animeTitle,
  required String animeUrl,
}) {
  final decoder = _TokyoInsiderLinkDecoder.fromDocument(htmlPage);
  final episodePages = <EpisodePage>[];

  for (final element in elements) {
    final mediaType = element.querySelector('em')?.text.trim().toLowerCase();
    if (mediaType != 'episode') continue;

    final episodeNumber = int.tryParse(
      element.querySelector('strong')?.text.trim() ?? '',
    );
    final dataA = element.attributes['data-a'];
    final dataB = element.attributes['data-b'];
    if (episodeNumber == null || dataA == null || dataB == null) {
      throw SourceException(
        message: "Could not parse encoded episode row",
        metadata: {
          "animeUrl": animeUrl,
          "episodeNumber": episodeNumber,
          "hasDataA": dataA != null,
          "hasDataB": dataB != null,
        },
      );
    }

    final path = decoder.decode(dataA + dataB);
    final uri = Uri.tryParse(path);
    if (uri == null || !uri.path.contains('/episode/')) {
      throw SourceException(
        message: "Decoded TokyoInsider episode url is invalid",
        metadata: {
          "animeUrl": animeUrl,
          "episodeNumber": episodeNumber,
          "decodedUrl": path,
        },
      );
    }
    episodePages.add(
      EpisodePage(
        animeTitle: animeTitle,
        title: element.parent?.text.trim() ?? element.text.trim(),
        url: _resolveUrl(path),
        episodeNumber: episodeNumber,
      ),
    );
  }
  return episodePages;
}

List<EpisodeDownloadLink> _parseLegacyEpisodeDownloadLinks({
  required List<Element> elements,
  required EpisodePage episodePage,
}) {
  return elements.map((element) {
    final path = element.attributes["href"];
    if (path == null) {
      throw SourceException(
        message: "Failed to find episode url",
        metadata: {"episodePage": episodePage},
      );
    }
    return _buildEpisodeDownloadLink(
      episodePage: episodePage,
      filename: element.text.trim(),
      url: _resolveUrl(path),
    );
  }).toList();
}

List<EpisodeDownloadLink> _parseEncodedEpisodeDownloadLinks({
  required Document htmlPage,
  required List<Element> elements,
  required EpisodePage episodePage,
}) {
  final decoder = _TokyoInsiderLinkDecoder.fromDocument(htmlPage);
  return [
    for (final element in elements)
      _buildEncodedEpisodeDownloadLink(
        decoder: decoder,
        element: element,
        episodePage: episodePage,
      ),
  ];
}

EpisodeDownloadLink _buildEncodedEpisodeDownloadLink({
  required _TokyoInsiderLinkDecoder decoder,
  required Element element,
  required EpisodePage episodePage,
}) {
  final dataA = element.attributes['data-a'];
  final dataB = element.attributes['data-b'];
  if (dataA == null || dataB == null) {
    throw SourceException(
      message: "Could not parse encoded download row",
      metadata: {
        "episodePage": episodePage,
        "hasDataA": dataA != null,
        "hasDataB": dataB != null,
      },
    );
  }

  final url = decoder.decode(dataA + dataB);
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !uri.hasScheme ||
      uri.host.isEmpty ||
      uri.pathSegments.isEmpty) {
    throw SourceException(
      message: "Decoded TokyoInsider download url is invalid",
      metadata: {"episodePage": episodePage, "decodedUrl": url},
    );
  }
  final filename = uri.pathSegments.last;
  if (filename.isEmpty) {
    throw SourceException(
      message: "Decoded TokyoInsider download filename is missing",
      metadata: {"episodePage": episodePage, "decodedUrl": url},
    );
  }
  return _buildEpisodeDownloadLink(
    episodePage: episodePage,
    filename: filename,
    url: url,
  );
}

EpisodeDownloadLink _buildEpisodeDownloadLink({
  required EpisodePage episodePage,
  required String filename,
  required String url,
}) {
  final parsed = anitomy_parser.parseFilename(filename);
  return EpisodeDownloadLink(
    filename: filename,
    url: url,
    animeTitle: episodePage.animeTitle,
    episodeTitle: episodePage.title,
    episodeNumber: parsed.episode ?? episodePage.episodeNumber,
    resolution: parsed.resolution ?? parseResolution(filename),
    language: parsed.language,
  );
}

class _TokyoInsiderLinkDecoder {
  final List<int> _key;

  const _TokyoInsiderLinkDecoder(this._key);

  factory _TokyoInsiderLinkDecoder.fromDocument(Document htmlPage) {
    final scripts = htmlPage
        .querySelectorAll('script')
        .map((element) => element.text)
        .join('\n');
    final seed = RegExp(
      r'''var\s+K\s*=\s*r13\(\s*"([^"]+)"''',
    ).firstMatch(scripts)?.group(1);
    if (seed == null || seed.isEmpty) {
      throw SourceException(
        message: "Could not find TokyoInsider download decoder key",
        metadata: const {},
      );
    }
    final key = _rot13(_reverse(seed)).codeUnits;
    return _TokyoInsiderLinkDecoder(key);
  }

  String decode(String payload) {
    try {
      final encoded = _rot13(_reverse(payload));
      final bytes = base64.decode(encoded);
      return String.fromCharCodes([
        for (var index = 0; index < bytes.length; index++)
          bytes[index] ^ _key[index % _key.length],
      ]);
    } on FormatException catch (error) {
      throw SourceException(
        message: "Could not decode TokyoInsider download url",
        metadata: {"error": error.message},
      );
    }
  }
}

String _reverse(String value) => value.split('').reversed.join();

String _rot13(String value) {
  return value.replaceAllMapped(RegExp('[a-zA-Z]'), (match) {
    final codeUnit = match.group(0)!.codeUnitAt(0);
    final base = codeUnit <= 90 ? 65 : 97;
    return String.fromCharCode((codeUnit - base + 13) % 26 + base);
  });
}

class Source {
  final Dio _dio;
  late final AnimeListCache _animeListCache;
  static final Source _instance = Source._internal();

  Source._internal() : _dio = GlobalDio.getInstance() {
    _animeListCache = AnimeListCache(dio: _dio);
  }

  static Source getInstance() => _instance;

  Future<List<AnimeResult>> search({required SearchParams params}) async {
    log.infoWithMetadata("Searching", metadata: {"params": params});
    final results = await _animeListCache.search(params: params);
    log.fineWithMetadata(
      "Searched",
      metadata: {"params": params, "results": results.length},
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
    final encodedElements = _parseEncodedDownloadRows(htmlPage);
    final legacyElements = parsePageResults(htmlPage);
    final targetElements = encodedElements.isNotEmpty
        ? encodedElements
        : legacyElements;
    _logHtmlResponseDiagnostics(
      operation: 'fetchEpisodePages',
      response: response,
      htmlPage: htmlPage,
      targetElements: targetElements,
      context: {'animeTitle': animeTitle, 'animeUrl': animeUrl},
    );
    late final List<EpisodePage> episodePages;
    try {
      episodePages = encodedElements.isNotEmpty
          ? _parseEncodedEpisodePages(
              htmlPage: htmlPage,
              elements: encodedElements,
              animeTitle: animeTitle,
              animeUrl: animeUrl,
            )
          : _parseLegacyEpisodePages(
              elements: legacyElements,
              animeTitle: animeTitle,
              animeUrl: animeUrl,
            );
    } catch (error, stackTrace) {
      log.warningWithMetadata(
        'Failed to parse TokyoInsider episode rows',
        metadata: {
          'animeTitle': animeTitle,
          'animeUrl': animeUrl,
          'encodedElementCount': encodedElements.length,
          'legacyElementCount': legacyElements.length,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      rethrow;
    }
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
    final encodedElements = _parseEncodedFileRows(htmlPage);
    final legacyElements = parsePageResults(htmlPage);
    final targetElements = encodedElements.isNotEmpty
        ? encodedElements
        : legacyElements;
    _logHtmlResponseDiagnostics(
      operation: 'fetchEpisodeDownloadLinks',
      response: response,
      htmlPage: htmlPage,
      targetElements: targetElements,
      context: {
        'animeTitle': episodePage.animeTitle,
        'episodeNumber': episodePage.episodeNumber,
        'episodeUrl': episodePage.url,
      },
    );
    late final List<EpisodeDownloadLink> episodeDownloadLinks;
    try {
      episodeDownloadLinks = encodedElements.isNotEmpty
          ? _parseEncodedEpisodeDownloadLinks(
              htmlPage: htmlPage,
              elements: encodedElements,
              episodePage: episodePage,
            )
          : _parseLegacyEpisodeDownloadLinks(
              elements: legacyElements,
              episodePage: episodePage,
            );
    } catch (error, stackTrace) {
      log.warningWithMetadata(
        'Failed to parse TokyoInsider episode download links',
        metadata: {
          'episodePage': episodePage,
          'encodedElementCount': encodedElements.length,
          'legacyElementCount': legacyElements.length,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      rethrow;
    }
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

int? _parseEpisodeNumber(String text) {
  final parsed = anitomy_parser.parseFilename(text);
  if (parsed.episode != null) return parsed.episode;
  final match = RegExp(
    r'(?:episode|ep\.?)\s*(\d+)',
    caseSensitive: false,
  ).firstMatch(text);
  if (match != null) {
    return int.tryParse(match.group(1)!);
  }
  final plainNumberMatch = RegExp(r'\b(\d{1,4})\b').firstMatch(text);
  return plainNumberMatch == null
      ? null
      : int.tryParse(plainNumberMatch.group(1)!);
}
