import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:html/dom.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/interceptors/cookie_manager.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/net/net_config.dart';
import 'package:senpwai/shared/source_directory/source_directory.dart';
import 'package:senpwai/sources/shared/shared.dart';

final log = Logger("senpwai.anime.sources.animeheaven");

class Constants {
  static String get baseUrl => SourceDirectory.instance.animeHeaven.baseUrl;
}

String _resolveUrl(String href) =>
    Uri.parse(Constants.baseUrl).resolve(href).toString();

class AnimeResult {
  final String title;
  final String url;

  /// Romaji title and aliases from the anime page; search results only carry
  /// [title].
  final List<String> alternativeTitles;

  const AnimeResult({
    required this.title,
    required this.url,
    this.alternativeTitles = const [],
  });

  List<String> get titles => [title, ...alternativeTitles];

  AnimeResult copyWith({List<String>? alternativeTitles}) => AnimeResult(
    title: title,
    url: url,
    alternativeTitles: alternativeTitles ?? this.alternativeTitles,
  );

  @override
  String toString() =>
      "AnimeResult(title: $title, alternativeTitles: $alternativeTitles, url: $url)";
}

class EpisodePage {
  final String animeTitle;

  /// Opaque per-episode key AnimeHeaven's gate page reads from a cookie.
  final String key;
  final int episodeNumber;

  const EpisodePage({
    required this.animeTitle,
    required this.key,
    required this.episodeNumber,
  });

  @override
  String toString() =>
      "EpisodePage(animeTitle: $animeTitle, key: $key, episodeNumber: $episodeNumber)";
}

List<AnimeResult> parseSearchResults(Document htmlPage) => [
  for (final anchor in htmlPage.querySelectorAll('div.similarname > a'))
    if (anchor.attributes['href'] case final href?)
      AnimeResult(title: anchor.text.trim(), url: _resolveUrl(href)),
];

final _searchSeparators = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
final _episodeKeyPattern = RegExp(r'^[0-9a-f]{32}$');

/// Parses the episode list of an anime page. AnimeHeaven only lists the
/// episodes it hosts, so gaps in long-running series are expected.
List<EpisodePage> parseEpisodePages(
  Document htmlPage, {
  required String animeTitle,
}) {
  final episodePages = <EpisodePage>[];
  for (final anchor in htmlPage.querySelectorAll('a[onclick^="gatea"]')) {
    final key = anchor.id;
    final number = num.tryParse(
      anchor.querySelector('.watch2')?.text.trim() ?? '',
    );
    if (!_episodeKeyPattern.hasMatch(key) || number == null) {
      throw SourceException(
        message: "Could not parse AnimeHeaven episode row",
        metadata: {"animeTitle": animeTitle, "html": anchor.outerHtml},
      );
    }
    // Fractional rows (e.g. One Piece 1150.5) are recaps outside AniList's
    // episode numbering, so no request can ask for them.
    if (number is! int) continue;
    episodePages.add(
      EpisodePage(animeTitle: animeTitle, key: key, episodeNumber: number),
    );
  }
  return episodePages;
}

/// The romaji line may append comma-separated aliases ("Jujutsu Kaisen, jjk"),
/// but romaji titles can contain commas too, so the full line is kept as well.
List<String> parseAlternativeTitles(Document htmlPage) {
  final line = htmlPage.querySelector('.infotitlejp')?.text.trim() ?? '';
  if (line.isEmpty) return const [];
  return {
    line,
    for (final alias in line.split(','))
      if (alias.trim() case final trimmed when trimmed.isNotEmpty) trimmed,
  }.toList();
}

String parseDownloadUrl(Document htmlPage) {
  final href = htmlPage
      .querySelectorAll('a[href*="video.mp4"]')
      .map((anchor) => anchor.attributes['href']!)
      .where((href) => Uri.tryParse(href)?.hasScheme ?? false)
      .firstOrNull;
  if (href == null) {
    throw SourceException(
      message: "Could not find AnimeHeaven download link",
      metadata: {
        "title": htmlPage.querySelector('title')?.text.trim(),
        "videoSourceCount": htmlPage.querySelectorAll('video source').length,
      },
    );
  }
  return href;
}

class Source {
  final Dio _dio;
  static final Source _instance = Source._internal();

  Source._internal() : _dio = GlobalDio.getInstance();

  static Source getInstance() => _instance;

  Options get _noCacheOptions => Options(
    extra: NetConfig.getInstance()
        .buildCacheOptions(policy: CachePolicy.noCache)
        .toExtra(),
  );

  /// AnimeHeaven matches every space-separated word literally, so punctuation
  /// glued to a word (e.g. `-Starting`) would otherwise hide valid results.
  Future<List<AnimeResult>> search({required String term}) async {
    await SourceDirectory.waitForRefresh();
    final response = await _dio.get(
      "${Constants.baseUrl}/search.php",
      queryParameters: {"s": term.replaceAll(_searchSeparators, ' ').trim()},
      options: _noCacheOptions,
    );
    return parseSearchResults(parseHtml(response.data));
  }

  Future<AnimeResult> fetchAlternativeTitles(AnimeResult result) async {
    await SourceDirectory.waitForRefresh();
    final response = await _dio.get(result.url, options: _noCacheOptions);
    return result.copyWith(
      alternativeTitles: parseAlternativeTitles(parseHtml(response.data)),
    );
  }

  Future<List<EpisodePage>> fetchEpisodePages({
    required String animeUrl,
    required String animeTitle,
  }) async {
    await SourceDirectory.waitForRefresh();
    final response = await _dio.get(animeUrl, options: _noCacheOptions);
    final episodePages = parseEpisodePages(
      parseHtml(response.data),
      animeTitle: animeTitle,
    );
    log.fineWithMetadata(
      "Fetched episode pages",
      metadata: {"animeUrl": animeUrl, "episodeCount": episodePages.length},
    );
    return episodePages;
  }

  /// AnimeHeaven's gate page renders whichever episode the `key` cookie names.
  Future<String> fetchDownloadUrl({required EpisodePage episodePage}) async {
    await SourceDirectory.waitForRefresh();
    final options = _noCacheOptions;
    final response = await _dio.get(
      "${Constants.baseUrl}/gate.php",
      options: options.copyWith(
        headers: {'Cookie': 'key=${episodePage.key}'},
        extra: {...?options.extra, skipCookieManagerExtraKey: true},
      ),
    );
    return parseDownloadUrl(parseHtml(response.data));
  }
}
