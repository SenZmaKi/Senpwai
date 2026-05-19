import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anitomy/anitomy.dart' as anitomy_parser;
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/sources/shared/matcher/nyaa.dart';
import 'package:senpwai/sources/shared/matcher/shared.dart';
import 'package:senpwai/sources/shared/shared.dart';

class NyaaDownloadPlanner {
  final NyaaMatcher _matcher;
  final Dio _dio;

  NyaaDownloadPlanner({NyaaMatcher? matcher, Dio? dio})
    : _matcher = matcher ?? NyaaMatcher(),
      _dio = dio ?? GlobalDio.getInstance();

  Future<PreparedDownloadBatch> plan(DownloadRequest request) async {
    final params = NyaaMatchParams(
      preferredResolution: request.resolution,
      preferredLanguage: request.language,
    );
    final requestedEpisodes = [
      for (
        var episode = request.startEpisode;
        episode <= request.endEpisode;
        episode++
      )
        episode,
    ];
    final notices = <DownloadNotice>[];
    final anime = request.anime;

    if (anime.format == AnilistFormat.movie) {
      final movieCandidates = await _matcher.matchMovie(anime, params);
      final moviePlan = await _planBatchCandidate(
        anime: anime,
        request: request,
        requestedEpisodes: requestedEpisodes,
        candidates: movieCandidates,
      );
      if (moviePlan == null) {
        throw const DownloadUserError(
          title: 'No usable torrent found',
          description:
              'Could not find a movie torrent whose files matched this title.',
        );
      }
      return PreparedDownloadBatch(
        jobs: [moviePlan],
        notices: notices,
        requiresUserReview: true,
      );
    }

    final shouldPreferEpisodes =
        anime.status == AnilistAiringStatus.releasing ||
        anime.status == AnilistAiringStatus.notYetReleased;

    if (!shouldPreferEpisodes) {
      final seasonCandidates = await _matcher.matchSeason(anime, params);
      final seasonPlan = await _planBatchCandidate(
        anime: anime,
        request: request,
        requestedEpisodes: requestedEpisodes,
        candidates: seasonCandidates,
      );
      if (seasonPlan != null) {
        return PreparedDownloadBatch(
          jobs: [seasonPlan],
          notices: notices,
          requiresUserReview: true,
        );
      }
      if (seasonCandidates.isNotEmpty) {
        notices.add(
          const DownloadNotice(
            level: DownloadNoticeLevel.warning,
            title: 'Season pack fallback',
            description:
                'No season torrent cleanly matched the requested episodes, so episode torrents will be used instead.',
          ),
        );
      }
    }

    final episodeMatches = await _matcher.matchEpisodes(
      anime,
      params,
      episodeNumbers: requestedEpisodes,
    );
    final jobs = <PreparedDownloadJob>[];
    for (final episodeMatch in episodeMatches) {
      final bestMatch = episodeMatch.matches.isEmpty
          ? null
          : episodeMatch.matches.first;
      if (bestMatch == null) {
        throw DownloadUserError(
          title: 'Episode torrent missing',
          description:
              'Could not find a usable torrent for episode ${episodeMatch.episodeNumber}.',
        );
      }
      final torrentData = await _fetchTorrentData(
        bestMatch.result.torrentFileUrl,
      );
      final inspected = await _inspectTorrentData(
        anime: anime,
        torrentData: torrentData,
        candidate: bestMatch,
        requestedEpisodes: {episodeMatch.episodeNumber},
        preferredLanguage: request.language,
      );
      final mappedFile = inspected.selectedFiles[episodeMatch.episodeNumber];
      if (mappedFile == null) {
        throw DownloadUserError(
          title: 'Episode file missing',
          description:
              'Torrent metadata did not expose a file for episode ${episodeMatch.episodeNumber}.',
        );
      }
      jobs.add(
        PreparedTorrentDownloadJob(
          source: AnimeSource.nyaa,
          animeTitle: anime.title.display,
          displayTitle: path.basename(mappedFile.entry.path),
          destinationDirectory: request.downloadFolder,
          totalBytes: mappedFile.entry.size,
          torrentData: torrentData,
          torrentName: bestMatch.result.filename,
          selectedFileIndices: [mappedFile.entry.index],
          selectedFilePaths: [
            path.join(request.downloadFolder, mappedFile.entry.path),
          ],
        ),
      );
    }

    if (jobs.isEmpty) {
      throw const DownloadUserError(
        title: 'No usable torrent found',
        description:
            'Could not build a torrent plan from the available Nyaa results.',
      );
    }

    return PreparedDownloadBatch(
      jobs: jobs,
      notices: notices,
      requiresUserReview: true,
    );
  }

  Future<PreparedTorrentDownloadJob?> _planBatchCandidate({
    required DownloadRequest request,
    required List<int> requestedEpisodes,
    required List<ScoredNyaaResult> candidates,
    required dynamic anime,
  }) async {
    for (final candidate in candidates.take(3)) {
      final torrentData = await _fetchTorrentData(
        candidate.result.torrentFileUrl,
      );
      final inspected = await _inspectTorrentData(
        anime: request.anime,
        torrentData: torrentData,
        candidate: candidate,
        requestedEpisodes: requestedEpisodes.toSet(),
        preferredLanguage: request.language,
      );
      if (!inspected.coversAllEpisodes) continue;
      return PreparedTorrentDownloadJob(
        source: AnimeSource.nyaa,
        animeTitle: request.anime.title.display,
        displayTitle: candidate.result.filename,
        destinationDirectory: request.downloadFolder,
        totalBytes: inspected.totalSelectedBytes,
        torrentData: torrentData,
        torrentName: candidate.result.filename,
        selectedFileIndices: inspected.selectedFiles.values
            .map((match) => match.entry.index)
            .toList(),
        selectedFilePaths: inspected.selectedFiles.values
            .map((match) => path.join(request.downloadFolder, match.entry.path))
            .toList(),
      );
    }
    return null;
  }

  Future<Uint8List> _fetchTorrentData(String url) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw const DownloadUserError(
        title: 'Torrent metadata unavailable',
        description: 'The torrent file could not be downloaded from Nyaa.',
      );
    }
    return Uint8List.fromList(data);
  }

  Future<_InspectedTorrent> _inspectTorrentData({
    required dynamic anime,
    required Uint8List torrentData,
    required ScoredNyaaResult candidate,
    required Set<int> requestedEpisodes,
    required Language preferredLanguage,
  }) async {
    final tempRoot = await Directory.systemTemp.createTemp('senpwai-nyaa-');
    final session = createSession();
    try {
      final handle = session.addTorrentData(
        torrentData: torrentData,
        savePath: tempRoot.path,
      );
      final files = handle.getFiles();
      final desiredSeason = anitomy_parser
          .parseFilename(anime.title.display)
          .season;
      final titleCandidates = anime.title.toTitleCandidates();
      final selectedFiles = <int, _MatchedTorrentFile>{};

      for (final file in files.where((entry) => _looksLikeVideo(entry.path))) {
        final parsed = anitomy_parser.parseFilename(path.basename(file.path));
        final episodeNumber = parsed.episode;
        if (episodeNumber == null ||
            !requestedEpisodes.contains(episodeNumber)) {
          continue;
        }
        if (parsed.language != null && parsed.language != preferredLanguage) {
          continue;
        }
        if (desiredSeason != null &&
            parsed.season != null &&
            parsed.season != desiredSeason) {
          continue;
        }
        final parsedTitle = parsed.title;
        if (parsedTitle != null &&
            bestTitleScore(titleCandidates, parsedTitle) <
                Constants.minMatchScore) {
          continue;
        }
        final current = selectedFiles[episodeNumber];
        final nextMatch = _MatchedTorrentFile(
          entry: file,
          resolution: parsed.resolution,
        );
        if (current == null ||
            _isBetterFileCandidate(current, nextMatch, candidate.resolution)) {
          selectedFiles[episodeNumber] = nextMatch;
        }
      }

      final totalSelectedBytes = selectedFiles.values.fold<int>(
        0,
        (sum, match) => sum + match.entry.size,
      );
      return _InspectedTorrent(
        selectedFiles: selectedFiles,
        requestedEpisodes: requestedEpisodes,
        totalSelectedBytes: totalSelectedBytes,
      );
    } on LibtorrentException catch (error) {
      throw DownloadUserError(
        title: 'Torrent metadata could not be inspected',
        description: error.message,
        cause: error,
      );
    } finally {
      session.close();
      await tempRoot.delete(recursive: true);
    }
  }

  static bool _looksLikeVideo(String filePath) {
    const videoExtensions = [
      '3g2',
      '3gp',
      'asf',
      'avi',
      'dv',
      'flv',
      'gxf',
      'm2ts',
      'm4a',
      'm4b',
      'm4p',
      'm4r',
      'm4v',
      'mkv',
      'mov',
      'mp4',
      'mpd',
      'mpeg',
      'mpg',
      'mxf',
      'nut',
      'ogm',
      'ogv',
      'swf',
      'ts',
      'vob',
      'webm',
      'wmv',
      'wtv',
    ];
    return videoExtensions.contains(path.extension(filePath).toLowerCase());
  }

  static bool _isBetterFileCandidate(
    _MatchedTorrentFile current,
    _MatchedTorrentFile next,
    Resolution preferredResolution,
  ) {
    final currentDiff = current.resolution == null
        ? 1 << 30
        : (current.resolution!.value - preferredResolution.value).abs();
    final nextDiff = next.resolution == null
        ? 1 << 30
        : (next.resolution!.value - preferredResolution.value).abs();
    if (nextDiff != currentDiff) {
      return nextDiff < currentDiff;
    }
    return next.entry.size > current.entry.size;
  }
}

class _InspectedTorrent {
  final Map<int, _MatchedTorrentFile> selectedFiles;
  final Set<int> requestedEpisodes;
  final int totalSelectedBytes;

  const _InspectedTorrent({
    required this.selectedFiles,
    required this.requestedEpisodes,
    required this.totalSelectedBytes,
  });

  bool get coversAllEpisodes =>
      selectedFiles.length == requestedEpisodes.length;
}

class _MatchedTorrentFile {
  final TorrentFileEntry entry;
  final Resolution? resolution;

  const _MatchedTorrentFile({required this.entry, required this.resolution});
}
