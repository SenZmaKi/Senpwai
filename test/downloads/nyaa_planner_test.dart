import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/planners/nyaa.dart';
import 'package:senpwai/sources/nyaa.dart' as nyaa;
import 'package:senpwai/sources/shared/matcher/nyaa.dart';
import 'package:senpwai/sources/shared/shared.dart';

import '../support/support.dart';

void main() {
  setUpAll(() async {
    await setupTestApp();
  });

  group('looksLikeVideoFile', () {
    test('accepts common video extensions returned by path.extension', () {
      expect(looksLikeVideoFile('Episode 01.mkv'), isTrue);
      expect(looksLikeVideoFile('/tmp/Season 01/Episode 01.MP4'), isTrue);
      expect(looksLikeVideoFile('movie.webm'), isTrue);
    });

    test('rejects non-video files', () {
      expect(looksLikeVideoFile('subs.ass'), isFalse);
      expect(looksLikeVideoFile('archive.zip'), isFalse);
      expect(looksLikeVideoFile('README'), isFalse);
    });
  });

  group('plan', () {
    test('plans a movie torrent with a title-matched video file', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'senpwai-nyaa-planner-test-',
      );
      _TorrentServer? server;
      try {
        final video = File(
          '${tempDir.path}/[Judas] Kimi no Na wa (Your Name) [BD 1080p] [Dual-Audio].mkv',
        );
        await video.writeAsBytes(List<int>.generate(4096, (i) => i % 251));
        final torrentData = createTorrentData(
          sourcePath: video.path,
          trackerUrl: 'http://127.0.0.1/announce',
        );

        server = await _TorrentServer.start({'/movie.torrent': torrentData});

        final planner = NyaaDownloadPlanner(
          matcher: _FakeNyaaMatcher(
            movieMatches: [_scoredResult(server.url('/movie.torrent'))],
          ),
        );
        final batch = await planner.plan(
          DownloadRequest(
            anime: _movie(),
            source: AnimeSource.nyaa,
            startEpisode: 1,
            endEpisode: 1,
            downloadFolder: tempDir.path,
            httpJobTitle: 'Your Name',
            resolution: Resolution.res1080p,
            language: Language.english,
          ),
        );

        expect(batch.jobs, hasLength(1));
        final job = batch.jobs.single as PreparedTorrentDownloadJob;
        expect(job.selectedFileIndices, [0]);
        expect(job.selectedFilePaths.single, '${tempDir.path}/Your Name.mkv');
        expect(job.displayTitle, 'Your Name.mkv');
        expect(job.totalBytes, video.lengthSync());
      } finally {
        await server?.close();
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'uses title matching only to resolve duplicate episode files',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'senpwai-nyaa-planner-test-',
        );
        _TorrentServer? server;
        try {
          final sourceDir = Directory('${tempDir.path}/source')..createSync();
          final wrong = File('${sourceDir.path}/Wrong Show - 01 [1080p].mkv');
          final right = File('${sourceDir.path}/Frieren - 01 [720p].mkv');
          await wrong.writeAsBytes(List<int>.filled(4096, 1));
          await right.writeAsBytes(List<int>.filled(2048, 2));
          final torrentData = createTorrentData(
            sourcePath: sourceDir.path,
            trackerUrl: 'http://127.0.0.1/announce',
          );
          server = await _TorrentServer.start({'/season.torrent': torrentData});

          final planner = NyaaDownloadPlanner(
            matcher: _FakeNyaaMatcher(
              seasonMatches: [_scoredResult(server.url('/season.torrent'))],
            ),
          );
          final batch = await planner.plan(
            DownloadRequest(
              anime: _series(),
              source: AnimeSource.nyaa,
              startEpisode: 1,
              endEpisode: 1,
              downloadFolder: tempDir.path,
              httpJobTitle: 'Frieren',
              resolution: Resolution.res1080p,
              language: Language.japanese,
            ),
          );

          expect(batch.jobs, hasLength(1));
          final job = batch.jobs.single as PreparedTorrentDownloadJob;
          expect(job.totalBytes, right.lengthSync());
        } finally {
          await server?.close();
          await tempDir.delete(recursive: true);
        }
      },
    );

    test('combines partial batch coverage with individual episodes', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'senpwai-nyaa-planner-test-',
      );
      _TorrentServer? server;
      try {
        final batchDir = Directory('${tempDir.path}/batch')..createSync();
        await File(
          '${batchDir.path}/Frieren - 01 [1080p].mkv',
        ).writeAsBytes(List<int>.filled(1024, 1));
        await File(
          '${batchDir.path}/Frieren - 02 [1080p].mkv',
        ).writeAsBytes(List<int>.filled(2048, 2));
        final episode3 = File('${tempDir.path}/Frieren - 03 [1080p].mkv');
        await episode3.writeAsBytes(List<int>.filled(4096, 3));

        final batchTorrent = createTorrentData(
          sourcePath: batchDir.path,
          trackerUrl: 'http://127.0.0.1/announce',
        );
        final episodeTorrent = createTorrentData(
          sourcePath: episode3.path,
          trackerUrl: 'http://127.0.0.1/announce',
        );
        server = await _TorrentServer.start({
          '/batch.torrent': batchTorrent,
          '/episode-3.torrent': episodeTorrent,
        });

        final planner = NyaaDownloadPlanner(
          matcher: _FakeNyaaMatcher(
            seasonMatches: [_scoredResult(server.url('/batch.torrent'))],
            episodeMatches: {
              3: [_scoredResult(server.url('/episode-3.torrent'))],
            },
          ),
        );
        final batch = await planner.plan(
          DownloadRequest(
            anime: _series(),
            source: AnimeSource.nyaa,
            startEpisode: 1,
            endEpisode: 3,
            downloadFolder: tempDir.path,
            httpJobTitle: 'Frieren',
            resolution: Resolution.res1080p,
            language: Language.japanese,
          ),
        );

        expect(batch.jobs, hasLength(2));
        expect(batch.nyaaEpisodeIssues, isEmpty);
        final batchJob = batch.jobs.first as PreparedTorrentDownloadJob;
        final episodeJob = batch.jobs.last as PreparedTorrentDownloadJob;
        expect(batchJob.reviewMetadata?.batchEpisodeNumbers, [1, 2]);
        expect(episodeJob.reviewMetadata?.episodeNumber, 3);
      } finally {
        await server?.close();
        await tempDir.delete(recursive: true);
      }
    });
  });
}

AnilistAnime _movie() => const AnilistAnime(
  id: 21519,
  title: AnilistTitle(
    romaji: 'Kimi no Na wa.',
    english: 'Your Name.',
    native: '君の名は。',
  ),
  format: AnilistFormat.movie,
  genres: [],
);

AnilistAnime _series() => const AnilistAnime(
  id: 154587,
  title: AnilistTitle(
    romaji: 'Sousou no Frieren',
    english: "Frieren: Beyond Journey's End",
    native: '葬送のフリーレン',
  ),
  format: AnilistFormat.tv,
  genres: [],
);

ScoredNyaaResult _scoredResult(String torrentFileUrl) => ScoredNyaaResult(
  result: nyaa.AnimeResult(
    filename: "[Judas] Frieren - Beyond Journey's End [BD 1080p] [Dual-Audio]",
    torrentFileUrl: torrentFileUrl,
    magnetUrl: 'magnet:?xt=urn:btih:$torrentFileUrl',
    sizeBytes: 4096,
    dateAdded: DateTime(2026),
    seeders: 1,
    leechers: 0,
    torrentFileDownloadCount: 1,
  ),
  score: 1,
  resolution: Resolution.res1080p,
  isCompleteSeason: true,
  searchQuery: 'Kimi no Na wa.',
);

class _FakeNyaaMatcher extends NyaaMatcher {
  final List<ScoredNyaaResult> movieMatches;
  final List<ScoredNyaaResult> seasonMatches;
  final Map<int, List<ScoredNyaaResult>> episodeMatches;

  _FakeNyaaMatcher({
    this.movieMatches = const [],
    this.seasonMatches = const [],
    this.episodeMatches = const {},
  });

  @override
  Future<List<ScoredNyaaResult>> matchMovie(
    AnilistAnimeBase<dynamic> anime,
    NyaaMatchParams params,
  ) async {
    return movieMatches;
  }

  @override
  Future<List<ScoredNyaaResult>> matchSeason(
    AnilistAnimeBase<dynamic> anime,
    NyaaMatchParams params,
  ) async {
    return seasonMatches;
  }

  @override
  Future<List<NyaaEpisodeMatch>> matchEpisodes(
    AnilistAnimeBase<dynamic> anime,
    NyaaMatchParams params, {
    required List<int> episodeNumbers,
  }) async {
    return [
      for (final episodeNumber in episodeNumbers)
        NyaaEpisodeMatch(
          episodeNumber: episodeNumber,
          matches: episodeMatches[episodeNumber] ?? const [],
        ),
    ];
  }

  @override
  Future<List<ScoredNyaaResult>> matchBroadCandidates(
    AnilistAnimeBase<dynamic> anime,
    NyaaMatchParams params,
  ) async {
    return const [];
  }
}

class _TorrentServer {
  final HttpServer _server;
  final Future<void> _done;

  _TorrentServer._(this._server, this._done);

  int get port => _server.port;

  String url(String path) => 'http://127.0.0.1:$port$path';

  static Future<_TorrentServer> start(Map<String, List<int>> torrents) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final done = server.listen((request) {
      final data = torrents[request.uri.path];
      if (data == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response
          ..headers.contentType = ContentType.binary
          ..add(data);
      }
      request.response.close();
    }).asFuture<void>();
    return _TorrentServer._(server, done);
  }

  Future<void> close() async {
    await _server.close(force: true);
    await _done;
  }
}
