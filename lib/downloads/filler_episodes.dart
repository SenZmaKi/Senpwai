import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:logging/logging.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/anitomy/anitomy.dart' as anitomy_parser;
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/net.dart';

const _animeFillerListHome = 'https://www.animefillerlist.com';
const _cacheDuration = Duration(hours: 24);

final _log = Logger('senpwai.downloads.filler_episodes');
final _parentheticalText = RegExp(r'\[[^\]]*\]|\([^)]*\)');
final _nonAlphanumeric = RegExp(r'[^\p{L}\p{N}]', unicode: true);
final _fillerListSuffix = RegExp(r'\s+Filler List\s*$', caseSensitive: false);

class AnimeFillerService {
  static final instance = AnimeFillerService();

  final Dio? _dioOverride;
  Map<String, List<_FillerShow>>? _showIndex;
  DateTime? _showIndexFetchedAt;
  Future<Map<String, List<_FillerShow>>>? _showIndexRequest;
  final Map<String, _CachedFillerPage> _pageCache = {};

  AnimeFillerService({Dio? dio}) : _dioOverride = dio;

  Dio get _dio => _dioOverride ?? GlobalDio.getInstance();

  Future<Set<int>> getFillerEpisodes({
    required AnilistAnimeBase anime,
    required int episodeCount,
  }) async {
    if (episodeCount <= 0 || _isSequel(anime.title)) return const {};

    try {
      final titles = anime.title.toTitleCandidates();
      final lookupKeys = titles
          .map(_lookupTitleKey)
          .where((key) => key.isNotEmpty)
          .toSet();
      if (lookupKeys.isEmpty) return const {};

      final showIndex = await _getShowIndex();
      final matches = <_FillerShow>[
        for (final key in lookupKeys) ...?showIndex[key],
      ];
      if (matches.isEmpty) return const {};

      final strictKeys = titles
          .map(_strictTitleKey)
          .where((key) => key.isNotEmpty)
          .toSet();
      matches.sort(
        (left, right) => _matchPriority(
          right,
          strictKeys,
        ).compareTo(_matchPriority(left, strictKeys)),
      );

      for (final show in matches.toSet()) {
        final page = await _getFillerPage(show.path);
        if (!_pageMatchesShow(page.title, show)) {
          _log.warningWithMetadata(
            'Ignored mismatched AnimeFillerList page',
            metadata: {
              'anime': anime.title.display,
              'listedTitle': show.title,
              'pageTitle': page.title,
              'path': show.path,
            },
          );
          continue;
        }
        if (page.episodes.isNotEmpty && page.episodes.last > episodeCount) {
          _log.infoWithMetadata(
            'Ignored filler list spanning beyond the selected anime entry',
            metadata: {
              'anime': anime.title.display,
              'episodeCount': episodeCount,
              'lastFillerEpisode': page.episodes.last,
            },
          );
          return const {};
        }
        return page.episodes.toSet();
      }
    } on Object catch (error, stackTrace) {
      _log.warningWithMetadata(
        'Filler lookup failed; continuing without filler filtering',
        metadata: {
          'anime': anime.title.display,
          'error': '$error',
          'stackTrace': '$stackTrace',
        },
      );
    }
    return const {};
  }

  Future<Map<String, List<_FillerShow>>> _getShowIndex() async {
    final now = DateTime.now();
    final cached = _showIndex;
    final fetchedAt = _showIndexFetchedAt;
    if (cached != null &&
        fetchedAt != null &&
        now.difference(fetchedAt) <= _cacheDuration) {
      return cached;
    }

    final activeRequest = _showIndexRequest;
    if (activeRequest != null) return activeRequest;

    final request = _fetchShowIndex();
    _showIndexRequest = request;
    try {
      final index = await request;
      _showIndex = index;
      _showIndexFetchedAt = DateTime.now();
      return index;
    } finally {
      if (identical(_showIndexRequest, request)) _showIndexRequest = null;
    }
  }

  Future<Map<String, List<_FillerShow>>> _fetchShowIndex() async {
    final response = await _dio.get<String>('$_animeFillerListHome/shows');
    final document = html_parser.parse(response.data);
    final showList = document.querySelector('#ShowList');
    if (showList == null) {
      throw const FormatException('AnimeFillerList show index is missing.');
    }

    final index = <String, List<_FillerShow>>{};
    for (final anchor in showList.querySelectorAll('li a[href]')) {
      final title = anchor.text.trim();
      final path = anchor.attributes['href']?.trim();
      final key = _lookupTitleKey(title);
      if (title.isEmpty || path == null || path.isEmpty || key.isEmpty) {
        continue;
      }
      index
          .putIfAbsent(key, () => [])
          .add(_FillerShow(title: title, path: path));
    }
    if (index.isEmpty) {
      throw const FormatException('AnimeFillerList show index is empty.');
    }
    return index;
  }

  Future<_FillerPage> _getFillerPage(String path) async {
    final now = DateTime.now();
    final cached = _pageCache[path];
    if (cached != null && now.difference(cached.fetchedAt) <= _cacheDuration) {
      return cached.page;
    }

    final uri = Uri.parse(_animeFillerListHome).resolve(path);
    final response = await _dio.get<String>(uri.toString());
    final document = html_parser.parse(response.data);
    final pageTitle = document.querySelector('h1')?.text.trim();
    final episodeTable = document.querySelector('table.EpisodeList');
    if (pageTitle == null || pageTitle.isEmpty || episodeTable == null) {
      throw FormatException('Invalid AnimeFillerList show page: $uri');
    }

    final episodes = <int>[];
    for (final row in episodeTable.querySelectorAll('tr.filler')) {
      final episode = int.tryParse(
        row.querySelector('td.Number')?.text.trim() ?? '',
      );
      if (episode != null && episode > 0) episodes.add(episode);
    }
    episodes.sort();
    final page = _FillerPage(
      title: pageTitle.replaceFirst(_fillerListSuffix, '').trim(),
      episodes: episodes,
    );
    _pageCache[path] = _CachedFillerPage(page: page, fetchedAt: now);
    return page;
  }
}

bool _isSequel(AnilistTitle title) {
  for (final candidate in title.toTitleCandidates()) {
    final season = anitomy_parser.parseFilename(candidate).season;
    if (season != null && season > 1) return true;
  }
  return false;
}

int _matchPriority(_FillerShow show, Set<String> strictKeys) =>
    strictKeys.contains(_strictTitleKey(show.title)) ? 1 : 0;

bool _pageMatchesShow(String pageTitle, _FillerShow show) {
  final strictPageTitle = _strictTitleKey(pageTitle);
  return strictPageTitle == _strictTitleKey(show.title) ||
      _lookupTitleKey(pageTitle) == _lookupTitleKey(show.title);
}

String _lookupTitleKey(String title) =>
    _strictTitleKey(title.replaceAll(_parentheticalText, ''));

String _strictTitleKey(String title) =>
    title.replaceAll('×', 'x').replaceAll(_nonAlphanumeric, '').toLowerCase();

class _FillerShow {
  final String title;
  final String path;

  const _FillerShow({required this.title, required this.path});

  @override
  bool operator ==(Object other) =>
      other is _FillerShow && other.title == title && other.path == path;

  @override
  int get hashCode => Object.hash(title, path);
}

class _FillerPage {
  final String title;
  final List<int> episodes;

  const _FillerPage({required this.title, required this.episodes});
}

class _CachedFillerPage {
  final _FillerPage page;
  final DateTime fetchedAt;

  const _CachedFillerPage({required this.page, required this.fetchedAt});
}
