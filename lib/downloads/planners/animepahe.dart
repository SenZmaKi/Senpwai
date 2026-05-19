import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/target_path_planner.dart';
import 'package:senpwai/shared/net/download/download.dart';
import 'package:senpwai/sources/animepahe.dart' as animepahe;
import 'package:senpwai/sources/shared/shared.dart';

class AnimePaheDownloadPlanner {
  final animepahe.Source _source;
  final DownloadTargetPlanner _targetPlanner;

  AnimePaheDownloadPlanner({
    animepahe.Source? source,
    DownloadTargetPlanner? targetPlanner,
  }) : _source = source ?? animepahe.Source.getInstance(),
       _targetPlanner = targetPlanner ?? const DownloadTargetPlanner();

  Future<PreparedDownloadBatch> plan({
    required DownloadRequest request,
    required animepahe.AnimeResult? animeMatch,
  }) async {
    if (animeMatch == null) {
      throw const DownloadUserError(
        title: 'AnimePahe unavailable',
        description: 'This anime does not currently have an AnimePahe match.',
      );
    }

    // Must be called before any AnimePahe network request.
    await animepahe.Source.ensureInitialized();
    final pageRange = await _source.computeEpisodePageRange(
      startEpisode: request.startEpisode,
      endEpisode: request.endEpisode,
      animeSession: animeMatch.session,
    );
    final firstPageSessions = await _source.fetchEpisodeSessions(
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
      for (
        var pageNum = pageRange.startPageNum;
        pageNum <= pageRange.endPageNum;
        pageNum++
      )
        _source.fetchEpisodeSessions(
          animeSession: animeMatch.session,
          pageNum: pageNum,
          pageJson: pageNum == 1 ? pageRange.firstPageJson : null,
        ),
    ]);
    final episodeSessions = episodeSessionsByPage
        .expand((page) => page)
        .toList();
    final selectedSessions = _source.findEpisodeSessionsWithinRange(
      animeSession: animeMatch.session,
      firstEpisode: firstPageSessions.first.number,
      startEpisode: request.startEpisode,
      endEpisode: request.endEpisode,
      episodeSessions: episodeSessions,
    );

    final notices = <DownloadNotice>[];
    final jobs = <PreparedDownloadJob>[];
    for (var index = 0; index < selectedSessions.length; index++) {
      final episodeSession = selectedSessions[index];
      final downloadLinks = await _source.fetchDownloadLinks(
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

      final selectedLink = _selectLink(
        downloadLinks,
        request,
        notices,
        episodeSession.number,
      );
      final directLink = await _source.fetchDirectDownloadLink(
        downloadLink: selectedLink,
      );
      final resolvedTarget = await Download.probeSingleFile(
        url: directLink.url,
        headers: {'Referer': directLink.refererUrl},
      );
      final plannedTarget = _targetPlanner.planEpisodeFile(
        directory: request.downloadFolder,
        jobTitle: request.httpJobTitle,
        sourceFileName: directLink.filename,
        resolvedUrl: resolvedTarget.resolvedUrl,
        dedupeSuffix: index == 0 ? null : '(${index + 1})',
      );
      jobs.add(
        PreparedHttpDownloadJob(
          source: AnimeSource.animepahe,
          animeTitle: request.anime.title.display,
          displayTitle: plannedTarget.fileName,
          destinationDirectory: plannedTarget.directory,
          totalBytes: resolvedTarget.sizeBytes,
          resolvedUrl: resolvedTarget.resolvedUrl,
          fileName: plannedTarget.fileName,
          headers: {'Referer': directLink.refererUrl},
          episodeNumber: directLink.episodeNumber,
        ),
      );
    }

    return PreparedDownloadBatch(jobs: jobs, notices: notices);
  }

  animepahe.DownloadLink _selectLink(
    List<animepahe.DownloadLink> links,
    DownloadRequest request,
    List<DownloadNotice> notices,
    int episodeNumber,
  ) {
    final languageMatches = links
        .where((link) => link.audioLanguage == request.language)
        .toList();
    final activeLanguagePool = languageMatches.isNotEmpty
        ? languageMatches
        : links;
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
    return _pickClosestResolution(
      activeLanguagePool,
      request.resolution,
      notices,
      episodeNumber,
    );
  }

  animepahe.DownloadLink _pickClosestResolution(
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
}
