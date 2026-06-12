import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/anitomy/anitomy.dart' as anitomy_parser;
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';
import 'package:senpwai/downloads/target_path_planner.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/sources/nyaa.dart' as nyaa;
import 'package:senpwai/sources/shared/matcher/nyaa.dart';
import 'package:senpwai/sources/shared/matcher/shared.dart';
import 'package:senpwai/sources/shared/shared.dart';

bool looksLikeVideoFile(String filePath) {
  const videoExtensions = {
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
  };
  final extension = path.extension(filePath).toLowerCase();
  if (extension.isEmpty) return false;
  return videoExtensions.contains(
    extension.startsWith('.') ? extension.substring(1) : extension,
  );
}

const _maxCandidateInspections = 15;

class NyaaDownloadPlanner {
  final NyaaMatcher _matcher;
  final Dio _dio;
  final nyaa.Source _source;
  final DownloadTargetPlanner _targetPlanner;

  NyaaDownloadPlanner({
    NyaaMatcher? matcher,
    Dio? dio,
    nyaa.Source? source,
    DownloadTargetPlanner? targetPlanner,
  }) : _matcher = matcher ?? NyaaMatcher(),
       _dio = dio ?? GlobalDio.getInstance(),
       _source = source ?? nyaa.Source.getInstance(),
       _targetPlanner = targetPlanner ?? const DownloadTargetPlanner();

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
      final moviePlan = await _planMovieCandidate(
        anime: anime,
        request: request,
        candidates: movieCandidates,
      );
      if (moviePlan == null) {
        throw const DownloadUserError(
          title: 'No usable torrent found',
          description:
              'Could not find a movie torrent whose files matched this title.',
        );
      }
      return PreparedDownloadBatch(jobs: [moviePlan], notices: notices);
    }

    final shouldPreferEpisodes =
        anime.status == AnilistAiringStatus.releasing ||
        anime.status == AnilistAiringStatus.notYetReleased;

    if (!shouldPreferEpisodes) {
      final seasonCandidates = await _matcher.matchSeason(anime, params);
      final seasonPlan = await _planBatchCandidate(
        request: request,
        requestedEpisodes: requestedEpisodes,
        candidates: seasonCandidates,
      );
      if (seasonPlan != null && seasonPlan.coversAllEpisodes) {
        return PreparedDownloadBatch(jobs: [seasonPlan.job], notices: notices);
      }
      if (seasonPlan != null) {
        notices.add(
          DownloadNotice(
            level: DownloadNoticeLevel.warning,
            title: 'Partial season pack',
            description:
                'A season torrent covered ${seasonPlan.episodeNumbers.length} of ${requestedEpisodes.length} requested episodes; using individual torrents for the rest.',
          ),
        );
      } else if (seasonCandidates.isNotEmpty) {
        notices.add(
          const DownloadNotice(
            level: DownloadNoticeLevel.warning,
            title: 'No matching season pack',
            description:
                'No season torrent cleanly covered the requested episodes; using individual episode torrents instead.',
          ),
        );
      }
      if (seasonPlan != null) {
        final plannedEpisodes = seasonPlan.episodeNumbers.toSet();
        final remainingEpisodes = requestedEpisodes
            .where((episode) => !plannedEpisodes.contains(episode))
            .toList();
        final remaining = await _planIndividualEpisodes(
          anime: anime,
          request: request,
          requestedEpisodes: remainingEpisodes,
          params: params,
        );
        return PreparedDownloadBatch(
          jobs: [seasonPlan.job, ...remaining.jobs],
          notices: notices,
          nyaaEpisodeIssues: remaining.nyaaEpisodeIssues,
        );
      }
    }

    final individualPlan = await _planIndividualEpisodes(
      anime: anime,
      request: request,
      requestedEpisodes: requestedEpisodes,
      params: params,
    );
    if (individualPlan.jobs.isEmpty &&
        individualPlan.nyaaEpisodeIssues.isEmpty) {
      throw const DownloadUserError(
        title: 'No usable torrent found',
        description:
            'Could not build a torrent plan from the available Nyaa results.',
      );
    }

    return PreparedDownloadBatch(
      jobs: individualPlan.jobs,
      notices: notices,
      nyaaEpisodeIssues: individualPlan.nyaaEpisodeIssues,
    );
  }

  Future<PreparedDownloadBatch> _planIndividualEpisodes({
    required AnilistAnimeBase<dynamic> anime,
    required DownloadRequest request,
    required List<int> requestedEpisodes,
    required NyaaMatchParams params,
  }) async {
    if (requestedEpisodes.isEmpty) {
      return const PreparedDownloadBatch(jobs: []);
    }

    final (episodeMatches, broadCandidates) = await (
      _matcher.matchEpisodes(anime, params, episodeNumbers: requestedEpisodes),
      _matcher.matchBroadCandidates(anime, params),
    ).wait;

    final matchesByEpisode = {
      for (final match in episodeMatches) match.episodeNumber: match,
    };
    final jobs = <PreparedDownloadJob>[];
    final unresolvedIssues = <NyaaEpisodeResolutionIssue>[];
    for (final episodeNumber in requestedEpisodes) {
      final episodeSpecificMatches =
          matchesByEpisode[episodeNumber]?.matches ?? const [];
      final job = await _planEpisodeFromCandidates(
        anime: anime,
        request: request,
        episodeNumber: episodeNumber,
        candidates: _mergeCandidates(episodeSpecificMatches, broadCandidates),
      );
      if (job != null) {
        jobs.add(job);
        continue;
      }

      unresolvedIssues.add(
        _buildEpisodeResolutionIssue(
          anime: anime,
          episodeNumber: episodeNumber,
          hadEpisodeSpecificMatches: episodeSpecificMatches.isNotEmpty,
          hadBroadCandidates: broadCandidates.isNotEmpty,
        ),
      );
    }

    if (jobs.isEmpty && unresolvedIssues.isEmpty) {
      return const PreparedDownloadBatch(jobs: []);
    }

    return PreparedDownloadBatch(
      jobs: jobs,
      nyaaEpisodeIssues: unresolvedIssues,
    );
  }

  Future<List<NyaaManualSearchCandidate>> searchManualCandidates({
    required DownloadRequest request,
    required int episodeNumber,
    required String query,
    NyaaManualSearchFilters filters = const NyaaManualSearchFilters(),
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const [];

    final results = await _source.search(
      params: nyaa.SearchParams(term: normalizedQuery, page: 1),
    );
    final desiredSeason = anitomy_parser
        .parseFilename(request.anime.title.display)
        .season;
    final titleCandidates = expandNyaaTitleCandidates(
      request.anime.title.toTitleCandidates(),
    );
    final manualCandidates = results.items
        .where((candidate) => candidate.seeders > 0)
        .map(
          (candidate) => _buildManualSearchCandidate(
            request: request,
            episodeNumber: episodeNumber,
            candidate: candidate,
            desiredSeason: desiredSeason,
            titleCandidates: titleCandidates,
            searchQuery: normalizedQuery,
          ),
        )
        .where(
          (candidate) =>
              (!filters.exactEpisodeOnly ||
                  candidate.matchesRequestedEpisode) &&
              (!filters.sameSeasonOnly || candidate.matchesRequestedSeason) &&
              (!filters.preferredLanguageOnly ||
                  candidate.matchesPreferredLanguage),
        )
        .toList();

    final comparator = switch (filters.sort) {
      NyaaManualSearchSort.smart =>
        (NyaaManualSearchCandidate a, NyaaManualSearchCandidate b) =>
            b.smartScore.compareTo(a.smartScore),
      NyaaManualSearchSort.seeders =>
        (NyaaManualSearchCandidate a, NyaaManualSearchCandidate b) =>
            b.result.seeders.compareTo(a.result.seeders),
      NyaaManualSearchSort.newest =>
        (NyaaManualSearchCandidate a, NyaaManualSearchCandidate b) =>
            b.result.dateAdded.compareTo(a.result.dateAdded),
      NyaaManualSearchSort.size =>
        (NyaaManualSearchCandidate a, NyaaManualSearchCandidate b) =>
            b.result.sizeBytes.compareTo(a.result.sizeBytes),
    };
    manualCandidates.sort(comparator);
    return manualCandidates;
  }

  Future<PreparedTorrentDownloadJob> planManualEpisode({
    required DownloadRequest request,
    required int episodeNumber,
    required NyaaManualSearchCandidate candidate,
  }) async {
    final job = await _buildEpisodeJobFromCandidate(
      anime: request.anime,
      request: request,
      episodeNumber: episodeNumber,
      candidate: ScoredNyaaResult(
        result: candidate.result,
        score: candidate.smartScore,
        resolution: candidate.resolution ?? request.resolution,
        isCompleteSeason: candidate.isBatch,
        searchQuery: candidate.searchQuery,
        isBroadSearch: candidate.isBatch,
      ),
    );
    if (job == null) {
      throw DownloadUserError(
        title: 'Episode file missing',
        description:
            'The selected torrent did not expose a usable file for episode $episodeNumber.',
      );
    }
    return job;
  }

  Future<PreparedTorrentDownloadJob?> _planMovieCandidate({
    required AnilistAnimeBase<dynamic> anime,
    required DownloadRequest request,
    required List<ScoredNyaaResult> candidates,
  }) async {
    for (final candidate in candidates.take(_maxCandidateInspections)) {
      final torrentData = await _fetchTorrentData(
        candidate.result.torrentFileUrl,
      );
      final matchedFile = await _inspectMovieTorrentData(
        anime: anime,
        torrentData: torrentData,
        candidate: candidate,
        preferredLanguage: request.language,
      );
      if (matchedFile == null) continue;

      final plannedTarget = _targetPlanner.planMovieFile(
        directory: request.downloadFolder,
        jobTitle: request.httpJobTitle,
        sourceFileName: matchedFile.entry.path,
        resolvedUrl: matchedFile.entry.path,
      );
      final targetFilePath = plannedTarget.filePath;
      return PreparedTorrentDownloadJob(
        source: AnimeSource.nyaa,
        animeTitle: anime.title.display,
        displayTitle: plannedTarget.fileName,
        destinationDirectory: request.downloadFolder,
        totalBytes: matchedFile.entry.size,
        torrentData: torrentData,
        torrentName: candidate.result.filename,
        selectedFileIndices: [matchedFile.entry.index],
        selectedFilePaths: [targetFilePath],
        renamedFilePaths: {matchedFile.entry.index: targetFilePath},
        reviewMetadata: _buildReviewMetadata(
          candidate: candidate,
          episodeNumber: null,
        ),
      );
    }
    return null;
  }

  Future<_BatchTorrentPlan?> _planBatchCandidate({
    required DownloadRequest request,
    required List<int> requestedEpisodes,
    required List<ScoredNyaaResult> candidates,
  }) async {
    _BatchTorrentPlan? bestPartialPlan;
    for (final candidate in candidates.take(_maxCandidateInspections)) {
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
      if (inspected.selectedFiles.isEmpty) continue;
      final orderedEpisodes = inspected.selectedFiles.keys.toList()..sort();
      final selectedFileIndices = <int>[];
      final selectedFilePaths = <String>[];
      final renamedFilePaths = <int, String>{};
      final episodeFileSizes = <int, int>{};
      for (final episodeNumber in orderedEpisodes) {
        final match = inspected.selectedFiles[episodeNumber]!;
        final plannedTarget = _targetPlanner.planEpisodeFile(
          directory: request.downloadFolder,
          jobTitle: request.httpJobTitle,
          episodeNumber: episodeNumber,
          sourceFileName: match.entry.path,
          resolvedUrl: match.entry.path,
        );
        final targetFilePath = plannedTarget.filePath;
        selectedFileIndices.add(match.entry.index);
        selectedFilePaths.add(targetFilePath);
        renamedFilePaths[match.entry.index] = targetFilePath;
        episodeFileSizes[episodeNumber] = match.entry.size;
      }
      final plan = _BatchTorrentPlan(
        job: PreparedTorrentDownloadJob(
          source: AnimeSource.nyaa,
          animeTitle: request.anime.title.display,
          displayTitle: candidate.result.filename,
          destinationDirectory: request.downloadFolder,
          totalBytes: inspected.totalSelectedBytes,
          torrentData: torrentData,
          torrentName: candidate.result.filename,
          selectedFileIndices: selectedFileIndices,
          selectedFilePaths: selectedFilePaths,
          renamedFilePaths: renamedFilePaths,
          reviewMetadata: _buildReviewMetadata(
            candidate: candidate,
            episodeNumber: null,
            batchEpisodeNumbers: orderedEpisodes,
            batchEpisodeFileSizes: episodeFileSizes,
          ),
        ),
        episodeNumbers: orderedEpisodes,
        requestedEpisodes: requestedEpisodes,
      );
      if (plan.coversAllEpisodes) {
        return plan;
      }
      if (bestPartialPlan == null ||
          plan.episodeNumbers.length > bestPartialPlan.episodeNumbers.length) {
        bestPartialPlan = plan;
      }
    }
    return bestPartialPlan;
  }

  Future<PreparedTorrentDownloadJob?> _planEpisodeFromCandidates({
    required AnilistAnimeBase<dynamic> anime,
    required DownloadRequest request,
    required int episodeNumber,
    required List<ScoredNyaaResult> candidates,
  }) async {
    DownloadUserError? lastRecoverableError;
    var candidateWithoutEpisodeFile = false;
    for (final candidate in candidates.take(_maxCandidateInspections)) {
      try {
        final job = await _buildEpisodeJobFromCandidate(
          anime: anime,
          request: request,
          episodeNumber: episodeNumber,
          candidate: candidate,
        );
        if (job != null) {
          return job;
        }
        candidateWithoutEpisodeFile = true;
      } on DownloadUserError catch (error) {
        lastRecoverableError = error;
      }
    }
    if (candidateWithoutEpisodeFile || candidates.isEmpty) {
      return null;
    }
    if (lastRecoverableError != null) {
      throw lastRecoverableError;
    }
    return null;
  }

  Future<PreparedTorrentDownloadJob?> _buildEpisodeJobFromCandidate({
    required AnilistAnimeBase<dynamic> anime,
    required DownloadRequest request,
    required int episodeNumber,
    required ScoredNyaaResult candidate,
  }) async {
    final torrentData = await _fetchTorrentData(
      candidate.result.torrentFileUrl,
    );
    final inspected = await _inspectTorrentData(
      anime: anime,
      torrentData: torrentData,
      candidate: candidate,
      requestedEpisodes: {episodeNumber},
      preferredLanguage: request.language,
    );
    final mappedFile = inspected.selectedFiles[episodeNumber];
    if (mappedFile == null) {
      return null;
    }
    final plannedTarget = _targetPlanner.planEpisodeFile(
      directory: request.downloadFolder,
      jobTitle: request.httpJobTitle,
      episodeNumber: episodeNumber,
      sourceFileName: mappedFile.entry.path,
      resolvedUrl: mappedFile.entry.path,
    );
    final targetFilePath = plannedTarget.filePath;
    return PreparedTorrentDownloadJob(
      source: AnimeSource.nyaa,
      animeTitle: anime.title.display,
      displayTitle: plannedTarget.fileName,
      destinationDirectory: request.downloadFolder,
      totalBytes: mappedFile.entry.size,
      torrentData: torrentData,
      torrentName: candidate.result.filename,
      selectedFileIndices: [mappedFile.entry.index],
      selectedFilePaths: [targetFilePath],
      renamedFilePaths: {mappedFile.entry.index: targetFilePath},
      reviewMetadata: _buildReviewMetadata(
        candidate: candidate,
        episodeNumber: episodeNumber,
      ),
    );
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
    required AnilistAnimeBase<dynamic> anime,
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
      final titleCandidates = expandNyaaTitleCandidates(
        anime.title.toTitleCandidates(),
      );
      final torrentParsed = anitomy_parser.parseFilename(
        candidate.result.filename,
      );
      final candidateFilesByEpisode = <int, List<_MatchedTorrentFile>>{};

      for (final file in files.where(
        (entry) => looksLikeVideoFile(entry.path),
      )) {
        final parsed = anitomy_parser.parseFilename(path.basename(file.path));
        final episodeNumber = parsed.episode;
        if (episodeNumber == null ||
            !requestedEpisodes.contains(episodeNumber)) {
          continue;
        }
        if (desiredSeason != null &&
            parsed.season != null &&
            parsed.season != desiredSeason) {
          continue;
        }
        if (!_matchesPreferredEffectiveLanguage(
          fileParsed: parsed,
          torrentParsed: torrentParsed,
          preferredLanguage: preferredLanguage,
        )) {
          continue;
        }
        final parsedTitle = parsed.title;
        final nextMatch = _MatchedTorrentFile(
          entry: file,
          resolution: _effectiveResolution(parsed, candidate),
          titleScore: parsedTitle == null
              ? null
              : bestTitleScore(titleCandidates, parsedTitle),
        );
        candidateFilesByEpisode
            .putIfAbsent(episodeNumber, () => [])
            .add(nextMatch);
      }

      final selectedFiles = <int, _MatchedTorrentFile>{};
      for (final entry in candidateFilesByEpisode.entries) {
        final candidates = entry.value;
        final titleMatchedCandidates = candidates
            .where(
              (candidate) =>
                  candidate.titleScore != null &&
                  candidate.titleScore! >= Constants.minMatchScore,
            )
            .toList();
        final pool = candidates.length > 1 && titleMatchedCandidates.isNotEmpty
            ? titleMatchedCandidates
            : candidates;
        selectedFiles[entry.key] = pool.reduce(
          (current, next) =>
              _isBetterFileCandidate(current, next, candidate.resolution)
              ? next
              : current,
        );
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

  Future<_MatchedTorrentFile?> _inspectMovieTorrentData({
    required AnilistAnimeBase<dynamic> anime,
    required Uint8List torrentData,
    required ScoredNyaaResult candidate,
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
      final titleCandidates = expandNyaaTitleCandidates(
        anime.title.toTitleCandidates(),
      );
      final torrentParsed = anitomy_parser.parseFilename(
        candidate.result.filename,
      );
      _MatchedTorrentFile? bestTitleMatch;
      _MatchedTorrentFile? bestVideoFallback;
      var videoCount = 0;

      for (final file in files.where(
        (entry) => looksLikeVideoFile(entry.path),
      )) {
        videoCount++;
        final parsed = anitomy_parser.parseFilename(path.basename(file.path));
        if (!_matchesPreferredEffectiveLanguage(
          fileParsed: parsed,
          torrentParsed: torrentParsed,
          preferredLanguage: preferredLanguage,
        )) {
          continue;
        }

        final match = _MatchedTorrentFile(
          entry: file,
          resolution: _effectiveResolution(parsed, candidate),
          titleScore: parsed.title == null
              ? null
              : bestTitleScore(titleCandidates, parsed.title!),
        );
        if (bestVideoFallback == null ||
            _isBetterFileCandidate(
              bestVideoFallback,
              match,
              candidate.resolution,
            )) {
          bestVideoFallback = match;
        }

        if (match.titleScore == null ||
            match.titleScore! < Constants.minMatchScore) {
          continue;
        }
        if (bestTitleMatch == null ||
            _isBetterFileCandidate(
              bestTitleMatch,
              match,
              candidate.resolution,
            )) {
          bestTitleMatch = match;
        }
      }

      if (bestTitleMatch != null) return bestTitleMatch;
      if (videoCount == 1) return bestVideoFallback;
      return null;
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

  Resolution _effectiveResolution(
    anitomy_parser.AnitomyParseResult fileParsed,
    ScoredNyaaResult torrentCandidate,
  ) {
    return fileParsed.resolution ?? torrentCandidate.resolution;
  }

  NyaaLanguageSignal _effectiveLanguageSignal({
    required anitomy_parser.AnitomyParseResult fileParsed,
    required anitomy_parser.AnitomyParseResult torrentParsed,
  }) {
    final fileSignal = classifyNyaaLanguageSignal(fileParsed);
    if (fileSignal != NyaaLanguageSignal.unknown) {
      return fileSignal;
    }
    return classifyNyaaLanguageSignal(torrentParsed);
  }

  bool _matchesPreferredEffectiveLanguage({
    required anitomy_parser.AnitomyParseResult fileParsed,
    required anitomy_parser.AnitomyParseResult torrentParsed,
    required Language preferredLanguage,
  }) {
    final signal = _effectiveLanguageSignal(
      fileParsed: fileParsed,
      torrentParsed: torrentParsed,
    );
    if (signal == NyaaLanguageSignal.dualAudio ||
        signal == NyaaLanguageSignal.unknown) {
      return true;
    }
    return switch (preferredLanguage) {
      Language.japanese => signal != NyaaLanguageSignal.dubbed,
      Language.english => signal != NyaaLanguageSignal.subbed,
    };
  }

  static bool _isBetterFileCandidate(
    _MatchedTorrentFile current,
    _MatchedTorrentFile next,
    Resolution preferredResolution,
  ) {
    final currentDiff = (current.resolution.value - preferredResolution.value)
        .abs();
    final nextDiff = (next.resolution.value - preferredResolution.value).abs();
    if (nextDiff != currentDiff) {
      return nextDiff < currentDiff;
    }
    return next.entry.size > current.entry.size;
  }

  List<ScoredNyaaResult> _mergeCandidates(
    List<ScoredNyaaResult> primary,
    List<ScoredNyaaResult> secondary,
  ) {
    final merged = <ScoredNyaaResult>[];
    final seenMagnetUrls = <String>{};
    for (final candidate in [...primary, ...secondary]) {
      if (!seenMagnetUrls.add(candidate.result.magnetUrl)) continue;
      merged.add(candidate);
    }
    return merged;
  }

  TorrentReviewMetadata _buildReviewMetadata({
    required ScoredNyaaResult candidate,
    required int? episodeNumber,
    List<int> batchEpisodeNumbers = const [],
    Map<int, int> batchEpisodeFileSizes = const {},
  }) {
    final parsed = anitomy_parser.parseFilename(candidate.result.filename);
    return TorrentReviewMetadata(
      episodeNumber: episodeNumber,
      resolution: candidate.resolution,
      seeders: candidate.result.seeders,
      languageLabel: classifyNyaaLanguageSignal(parsed).label,
      isBatch: candidate.isCompleteSeason,
      searchConfiguration: NyaaSearchConfiguration(
        query: candidate.searchQuery,
        filters: NyaaManualSearchFilters(
          exactEpisodeOnly: !candidate.isBroadSearch,
          sameSeasonOnly: true,
          preferredLanguageOnly: true,
        ),
      ),
      batchEpisodeNumbers: batchEpisodeNumbers,
      batchEpisodeFileSizes: batchEpisodeFileSizes,
    );
  }

  NyaaEpisodeResolutionIssue _buildEpisodeResolutionIssue({
    required AnilistAnimeBase<dynamic> anime,
    required int episodeNumber,
    required bool hadEpisodeSpecificMatches,
    required bool hadBroadCandidates,
  }) {
    final description = switch ((
      hadEpisodeSpecificMatches,
      hadBroadCandidates,
    )) {
      (false, false) =>
        'Automatic matching could not find a confident Nyaa result for this episode, so your help is needed.',
      (true, false) =>
        'Episode-specific torrents were found, but none exposed a clean file mapping for this episode.',
      (false, true) =>
        'Broad series candidates were found, but none contained a usable file for this episode.',
      (true, true) =>
        'Both episode-specific and broad series candidates were tried, but this episode still needs manual selection.',
    };
    return NyaaEpisodeResolutionIssue(
      episodeNumber: episodeNumber,
      title: 'Episode $episodeNumber needs guidance',
      description: description,
      searchConfiguration: NyaaSearchConfiguration(
        query: preferredNyaaEpisodeSearchTerm(
          anime.title.toTitleCandidates(),
          episodeNumber,
        ),
      ),
    );
  }

  NyaaManualSearchCandidate _buildManualSearchCandidate({
    required DownloadRequest request,
    required int episodeNumber,
    required nyaa.AnimeResult candidate,
    required int? desiredSeason,
    required List<String> titleCandidates,
    required String searchQuery,
  }) {
    final parsed = anitomy_parser.parseFilename(candidate.filename);
    final languageSignal = classifyNyaaLanguageSignal(parsed);
    final parsedEpisodeNumber = parsed.episode;
    final parsedSeasonNumber = parsed.season;
    final parsedTitle = parsed.title;
    final titleScore = parsedTitle == null
        ? 0.0
        : bestTitleScore(titleCandidates, parsedTitle).toDouble();
    final matchesRequestedEpisode = parsedEpisodeNumber == episodeNumber;
    final matchesRequestedSeason =
        desiredSeason == null ||
        parsedSeasonNumber == null ||
        parsedSeasonNumber == desiredSeason;
    final matchesLanguage = matchesPreferredNyaaLanguage(
      parsed,
      request.language,
    );
    final resolution = parsed.resolution;
    final resolutionScore = resolution == null
        ? 0.15
        : 1 -
              (((resolution.value - request.resolution.value).abs() /
                      Resolution.res4320p.value)
                  .clamp(0.0, 1.0));
    final smartScore =
        (matchesRequestedEpisode ? 2.2 : 0) +
        (matchesRequestedSeason ? 0.5 : 0) +
        (matchesLanguage ? 0.6 : 0) +
        (titleScore / 100) +
        resolutionScore +
        (candidate.seeders / 100).clamp(0, 0.8) +
        (parsedEpisodeNumber == null ? 0.15 : 0);
    return NyaaManualSearchCandidate(
      result: candidate,
      parsedEpisodeNumber: parsedEpisodeNumber,
      parsedSeasonNumber: parsedSeasonNumber,
      resolution: resolution,
      languageSignal: languageSignal,
      titleScore: titleScore,
      matchesRequestedEpisode: matchesRequestedEpisode,
      matchesRequestedSeason: matchesRequestedSeason,
      matchesPreferredLanguage: matchesLanguage,
      isBatch: parsedEpisodeNumber == null,
      smartScore: smartScore,
      searchQuery: searchQuery,
    );
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

class _BatchTorrentPlan {
  final PreparedTorrentDownloadJob job;
  final List<int> episodeNumbers;
  final List<int> requestedEpisodes;

  const _BatchTorrentPlan({
    required this.job,
    required this.episodeNumbers,
    required this.requestedEpisodes,
  });

  bool get coversAllEpisodes =>
      episodeNumbers.length == requestedEpisodes.length;
}

class _MatchedTorrentFile {
  final TorrentFileEntry entry;
  final Resolution resolution;
  final int? titleScore;

  const _MatchedTorrentFile({
    required this.entry,
    required this.resolution,
    this.titleScore,
  });
}
