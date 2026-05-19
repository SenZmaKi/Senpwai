import 'dart:async';

import 'package:path/path.dart' as path;
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/nyaa_planner.dart';
import 'package:senpwai/shared/net/download/download.dart';
import 'package:senpwai/shared/net/download/shared.dart';
import 'package:senpwai/sources/animepahe.dart' as animepahe;
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/sources/tokyoinsider.dart' as tokyoinsider;

class AnimeDownloadCoordinator {
  final animepahe.Source _animepaheSource;
  final tokyoinsider.Source _tokyoinsiderSource;
  final NyaaDownloadPlanner _nyaaPlanner;

  AnimeDownloadCoordinator({
    animepahe.Source? animepaheSource,
    tokyoinsider.Source? tokyoinsiderSource,
    NyaaDownloadPlanner? nyaaPlanner,
  }) : _animepaheSource = animepaheSource ?? animepahe.Source(),
       _tokyoinsiderSource = tokyoinsiderSource ?? tokyoinsider.Source(),
       _nyaaPlanner = nyaaPlanner ?? NyaaDownloadPlanner();

  Future<PreparedDownloadBatch> plan({
    required DownloadRequest request,
    animepahe.AnimeResult? animepaheMatch,
    tokyoinsider.AnimeResult? tokyoinsiderMatch,
  }) async {
    return switch (request.source) {
      RequestedDownloadSource.animepahe => _planAnimePahe(
          request: request,
          animeMatch: animepaheMatch,
        ),
      RequestedDownloadSource.tokyoinsider => _planTokyoInsider(
          request: request,
          animeMatch: tokyoinsiderMatch,
        ),
      RequestedDownloadSource.nyaa => _nyaaPlanner.plan(request),
    };
  }

  Future<PreparedDownloadBatch> _planAnimePahe({
    required DownloadRequest request,
    required animepahe.AnimeResult? animeMatch,
  }) async {
    if (animeMatch == null) {
      throw const DownloadUserError(
        title: 'AnimePahe unavailable',
        description: 'This anime does not currently have an AnimePahe match.',
      );
    }

    await animepahe.Source.ensureInitialized();
    final pageRange = await _animepaheSource.computeEpisodePageRange(
      startEpisode: request.startEpisode,
      endEpisode: request.endEpisode,
      animeSession: animeMatch.session,
    );
    final firstPageSessions = await _animepaheSource.fetchEpisodeSessions(
      animeSession: animeMatch.session,
      pageNum: 1,
      pageJson: pageRange.firstPageJson,
    );
    if (firstPageSessions.isEmpty) {
      throw const DownloadUserError(
        title: 'AnimePahe episodes unavailable',
        description: 'AnimePahe did not return any episode sessions.',
      );
    }
    final episodeSessionsByPage = await Future.wait([
      for (var pageNum = pageRange.startPageNum;
          pageNum <= pageRange.endPageNum;
          pageNum++)
        _animepaheSource.fetchEpisodeSessions(
          animeSession: animeMatch.session,
          pageNum: pageNum,
          pageJson: pageNum == 1 ? pageRange.firstPageJson : null,
        ),
    ]);
    final episodeSessions = episodeSessionsByPage.expand((page) => page).toList();
    final selectedSessions = _animepaheSource.findEpisodeSessionsWithinRange(
      animeSession: animeMatch.session,
      firstEpisode: firstPageSessions.first.number,
      startEpisode: request.startEpisode,
      endEpisode: request.endEpisode,
      episodeSessions: episodeSessions,
    );

    final notices = <DownloadNotice>[];
    final jobs = await Future.wait(
      selectedSessions.map((episodeSession) async {
        final downloadLinks = await _animepaheSource.fetchDownloadLinks(
          animeTitle: animeMatch.title,
          animeSession: animeMatch.session,
          episodeSession: episodeSession,
        );
        if (downloadLinks.isEmpty) {
          throw DownloadUserError(
            title: 'AnimePahe link missing',
            description:
                'Episode ${episodeSession.number} has no download links on AnimePahe.',
          );
        }
        final selectedLink = _selectAnimePaheLink(
          downloadLinks,
          request,
          notices,
          episodeSession.number,
        );
        final directLink = await _animepaheSource.fetchDirectDownloadLink(
          downloadLink: selectedLink,
        );
        final resolvedTarget = await Download.probeSingleFile(
          url: directLink.url,
          headers: {'Referer': directLink.refererUrl},
        );
        final fileName = _resolveFileName(directLink.filename, resolvedTarget);
        return PreparedHttpDownloadJob(
          source: RequestedDownloadSource.animepahe,
          animeTitle: request.anime.title.display,
          displayTitle: fileName,
          destinationDirectory: request.downloadFolder,
          totalBytes: resolvedTarget.sizeBytes,
          resolvedUrl: resolvedTarget.resolvedUrl,
          fileName: fileName,
          headers: {'Referer': directLink.refererUrl},
          episodeNumber: directLink.episodeNumber,
        );
      }),
    );

    return PreparedDownloadBatch(jobs: jobs, notices: notices);
  }

  Future<PreparedDownloadBatch> _planTokyoInsider({
    required DownloadRequest request,
    required tokyoinsider.AnimeResult? animeMatch,
  }) async {
    if (animeMatch == null) {
      throw const DownloadUserError(
        title: 'TokyoInsider unavailable',
        description:
            'This anime does not currently have a TokyoInsider match.',
      );
    }

    final episodePages = await _tokyoinsiderSource.fetchEpisodePages(
      animeUrl: animeMatch.url,
      animeTitle: animeMatch.title,
    );
    final pagesByEpisode = <int, tokyoinsider.EpisodePage>{};
    for (final page in episodePages) {
      pagesByEpisode.putIfAbsent(page.episodeNumber, () => page);
    }
    final missingEpisodes = [
      for (var episode = request.startEpisode; episode <= request.endEpisode; episode++)
        if (!pagesByEpisode.containsKey(episode)) episode,
    ];
    if (missingEpisodes.isNotEmpty) {
      throw DownloadUserError(
        title: 'TokyoInsider episodes missing',
        description:
            'TokyoInsider did not expose pages for episodes ${missingEpisodes.join(', ')}.',
      );
    }

    final notices = <DownloadNotice>[];
    final selectedPages = [
      for (var episode = request.startEpisode; episode <= request.endEpisode; episode++)
        pagesByEpisode[episode]!,
    ];
    final jobs = await Future.wait(
      selectedPages.map((episodePage) async {
        final downloadLinks = await _tokyoinsiderSource.fetchEpisodeDownloadLinks(
          episodePage: episodePage,
        );
        if (downloadLinks.isEmpty) {
          throw DownloadUserError(
            title: 'TokyoInsider link missing',
            description:
                'Episode ${episodePage.episodeNumber} has no download links on TokyoInsider.',
          );
        }
        final selectedLink = _selectTokyoInsiderLink(
          downloadLinks,
          request,
          notices,
          episodePage.episodeNumber,
        );
        final resolvedTarget = await Download.probeSingleFile(
          url: selectedLink.url,
        );
        final fileName = _resolveFileName(selectedLink.filename, resolvedTarget);
        return PreparedHttpDownloadJob(
          source: RequestedDownloadSource.tokyoinsider,
          animeTitle: request.anime.title.display,
          displayTitle: fileName,
          destinationDirectory: request.downloadFolder,
          totalBytes: resolvedTarget.sizeBytes,
          resolvedUrl: resolvedTarget.resolvedUrl,
          fileName: fileName,
          episodeNumber: selectedLink.episodeNumber,
        );
      }),
    );
    return PreparedDownloadBatch(jobs: jobs, notices: notices);
  }

  animepahe.DownloadLink _selectAnimePaheLink(
    List<animepahe.DownloadLink> links,
    DownloadRequest request,
    List<DownloadNotice> notices,
    int episodeNumber,
  ) {
    final languageMatches = links
        .where((link) => link.audioLanguage == request.language)
        .toList();
    final activeLanguagePool = languageMatches.isNotEmpty ? languageMatches : links;
    if (languageMatches.isEmpty) {
      notices.add(
        DownloadNotice(
          level: DownloadNoticeLevel.warning,
          title: 'Audio fallback',
          description:
              'AnimePahe episode $episodeNumber is not available in ${request.language}; using ${activeLanguagePool.first.audioLanguage}.',
        ),
      );
    }
    return _pickClosestAnimePaheResolution(
      activeLanguagePool,
      request.resolution,
      notices,
      episodeNumber,
    );
  }

  animepahe.DownloadLink _pickClosestAnimePaheResolution(
    List<animepahe.DownloadLink> links,
    Resolution preferredResolution,
    List<DownloadNotice> notices,
    int episodeNumber,
  ) {
    links.sort((a, b) {
      final aDiff = (a.resolution.value - preferredResolution.value).abs();
      final bDiff = (b.resolution.value - preferredResolution.value).abs();
      if (aDiff != bDiff) return aDiff.compareTo(bDiff);
      return a.estimatedSizeBytes.compareTo(b.estimatedSizeBytes);
    });
    final chosen = links.first;
    if (chosen.resolution != preferredResolution) {
      notices.add(
        DownloadNotice(
          level: DownloadNoticeLevel.warning,
          title: 'Quality fallback',
          description:
              'AnimePahe episode $episodeNumber is not available in $preferredResolution; using ${chosen.resolution}.',
        ),
      );
    }
    return chosen;
  }

  tokyoinsider.EpisodeDownloadLink _selectTokyoInsiderLink(
    List<tokyoinsider.EpisodeDownloadLink> links,
    DownloadRequest request,
    List<DownloadNotice> notices,
    int episodeNumber,
  ) {
    final exactLanguage = links
        .where((link) => link.language == request.language)
        .toList();
    final unknownLanguage = links.where((link) => link.language == null).toList();
    final languagePool = exactLanguage.isNotEmpty
        ? exactLanguage
        : (unknownLanguage.isNotEmpty ? unknownLanguage : links);

    if (exactLanguage.isEmpty) {
      final description = unknownLanguage.isNotEmpty
          ? 'TokyoInsider episode $episodeNumber does not label audio language; using the closest quality match.'
          : 'TokyoInsider episode $episodeNumber is not available in ${request.language}; using ${languagePool.first.language ?? 'an unlabeled track'}.';
      notices.add(
        DownloadNotice(
          level: DownloadNoticeLevel.warning,
          title: 'Audio fallback',
          description: description,
        ),
      );
    }

    final exactResolution = languagePool
        .where((link) => link.resolution == request.resolution)
        .toList();
    if (exactResolution.isNotEmpty) {
      return exactResolution.first;
    }

    final withResolution = languagePool
      ..sort((a, b) {
        final aResolution = a.resolution?.value ?? 0;
        final bResolution = b.resolution?.value ?? 0;
        final aDiff = (aResolution - request.resolution.value).abs();
        final bDiff = (bResolution - request.resolution.value).abs();
        if (aDiff != bDiff) return aDiff.compareTo(bDiff);
        return a.filename.compareTo(b.filename);
      });
    final chosen = withResolution.first;
    if (chosen.resolution != null && chosen.resolution != request.resolution) {
      notices.add(
        DownloadNotice(
          level: DownloadNoticeLevel.warning,
          title: 'Quality fallback',
          description:
              'TokyoInsider episode $episodeNumber is not available in ${request.resolution}; using ${chosen.resolution}.',
        ),
      );
    }
    return chosen;
  }

  static String _resolveFileName(
    String originalFileName,
    ResolvedDownloadTarget target,
  ) {
    final sanitizedOriginal = path.basename(originalFileName.trim());
    if (path.extension(sanitizedOriginal).isNotEmpty) {
      return sanitizedOriginal;
    }
    final resolvedName = path.basename(Uri.parse(target.resolvedUrl).path);
    if (resolvedName.isNotEmpty && path.extension(resolvedName).isNotEmpty) {
      return resolvedName;
    }
    return path.extension(sanitizedOriginal).isEmpty
        ? '$sanitizedOriginal.bin'
        : sanitizedOriginal;
  }
}
