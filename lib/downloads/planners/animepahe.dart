import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/planners/fallback_notice_collector.dart';
import 'package:senpwai/downloads/target_path_planner.dart';
import 'package:senpwai/shared/net/download/download.dart';
import 'package:senpwai/shared/net/request_cancellation_scope.dart';
import 'package:senpwai/shared/parallel.dart';
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
    DownloadPlanningProgressCallback? onProgress,
  }) async {
    final requestedEpisodes = request.episodeNumbers;
    if (requestedEpisodes.isEmpty) {
      return const PreparedDownloadBatch(jobs: []);
    }
    if (animeMatch == null) {
      throw const DownloadUserError(
        title: 'AnimePahe unavailable',
        description: 'This anime does not currently have an AnimePahe match.',
      );
    }

    final totalEpisodes = requestedEpisodes.length;
    var completedEpisodes = 0;
    var completedSteps = 0;
    final totalSteps = totalEpisodes * 3;
    void report(String activity) => onProgress?.call(
      DownloadPlanningProgress(
        completedEpisodes: completedEpisodes,
        totalEpisodes: totalEpisodes,
        completedSteps: completedSteps,
        totalSteps: totalSteps,
        activity: activity,
      ),
    );
    report('Finding episodes');

    // Must be called before any AnimePahe network request.
    await animepahe.Source.ensureInitialized();
    final pageRange = await _source.computeEpisodePageRange(
      startEpisode: requestedEpisodes.first,
      endEpisode: requestedEpisodes.last,
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

    final episodeSessionsByPage = await parallelMapOrdered(
      [
        for (
          var pageNum = pageRange.startPageNum;
          pageNum <= pageRange.endPageNum;
          pageNum++
        )
          pageNum,
      ],
      maxConcurrent: maxParallelSourceRequests,
      operation: (pageNum) => _source.fetchEpisodeSessions(
        animeSession: animeMatch.session,
        pageNum: pageNum,
        pageJson: pageNum == 1 ? pageRange.firstPageJson : null,
      ),
    );
    final episodeSessions = episodeSessionsByPage
        .expand((page) => page)
        .toList();
    final selectedSessions = _source
        .findEpisodeSessionsWithinRange(
          animeSession: animeMatch.session,
          firstEpisode: firstPageSessions.first.number,
          startEpisode: requestedEpisodes.first,
          endEpisode: requestedEpisodes.last,
          episodeSessions: episodeSessions,
        )
        .where((session) => requestedEpisodes.contains(session.number))
        .toList();
    throwIfRequestScopeCancelled();
    final notices = <DownloadNotice>[];
    final fallbackNotices = FallbackNoticeCollector(
      sourceName: AnimeSource.animepahe.label,
    );
    report('Loading episode links');
    final episodeLinks = await parallelMapOrdered(
      selectedSessions,
      maxConcurrent: maxParallelSourceRequests,
      operation: (episodeSession) async {
        throwIfRequestScopeCancelled();
        final links = await _source.fetchDownloadLinks(
          animeTitle: animeMatch.title,
          animeSession: animeMatch.session,
          episodeSession: episodeSession,
        );
        throwIfRequestScopeCancelled();
        completedSteps++;
        report('Loaded episode ${episodeSession.number} links');
        return (episodeSession: episodeSession, links: links);
      },
    );

    final selectedLinks = <animepahe.DownloadLink>[];
    for (final (:episodeSession, :links) in episodeLinks) {
      final downloadLinks = links;
      if (downloadLinks.isEmpty) {
        throw DownloadUserError(
          title: 'AnimePahe link missing',
          description:
              'Episode ${episodeSession.number} has no download links on AnimePahe.',
        );
      }

      selectedLinks.add(
        _selectLink(
          downloadLinks,
          request,
          fallbackNotices,
          episodeSession.number,
        ),
      );
    }

    // Each worker enters the single Kwik navigation lane, then releases it
    // before probing the resolved media URL. This keeps Kwik serialized while
    // allowing up to five native probes to overlap with later resolutions.
    final kwikLane = AsyncLimiter(1);
    final jobs =
        await parallelMapOrdered<animepahe.DownloadLink, PreparedDownloadJob>(
          selectedLinks,
          maxConcurrent: maxParallelSourceRequests,
          operation: (selectedLink) async {
            throwIfRequestScopeCancelled();
            final directLink = await kwikLane.run(() async {
              throwIfRequestScopeCancelled();
              report('Resolving episode ${selectedLink.episodeNumber}');
              final link = await _source.fetchDirectDownloadLink(
                downloadLink: selectedLink,
              );
              throwIfRequestScopeCancelled();
              completedSteps++;
              report('Resolved episode ${selectedLink.episodeNumber}');
              return link;
            });
            report('Checking episode ${directLink.episodeNumber}');
            final resolvedTarget = await Download.probeSingleFile(
              url: directLink.url,
              headers: {'Referer': directLink.refererUrl},
            );
            throwIfRequestScopeCancelled();
            final plannedTarget = _targetPlanner.planEpisodeFile(
              directory: request.downloadFolder,
              jobTitle: request.fileTitle,
              episodeNumber: directLink.episodeNumber,
              seasonNumber: request.fileSeasonNumber,
              sourceFileName: directLink.filename,
              resolvedUrl: resolvedTarget.resolvedUrl,
              suggestedFileName: resolvedTarget.suggestedFileName,
              contentType: resolvedTarget.contentType,
            );
            final job = PreparedHttpDownloadJob(
              source: AnimeSource.animepahe,
              animeTitle: request.anime.title.display,
              displayTitle: plannedTarget.fileName,
              destinationDirectory: plannedTarget.directory,
              totalBytes: resolvedTarget.sizeBytes,
              resolvedUrl: resolvedTarget.resolvedUrl,
              fileName: plannedTarget.fileName,
              headers: {'Referer': directLink.refererUrl},
              episodeNumber: directLink.episodeNumber,
            );
            completedSteps++;
            completedEpisodes++;
            report('Prepared episode ${directLink.episodeNumber}');
            return job;
          },
        );

    notices.addAll(fallbackNotices.build());
    return PreparedDownloadBatch(jobs: jobs, notices: notices);
  }

  animepahe.DownloadLink _selectLink(
    List<animepahe.DownloadLink> links,
    DownloadRequest request,
    FallbackNoticeCollector fallbackNotices,
    int episodeNumber,
  ) {
    final languageMatches = links
        .where((link) => link.audioLanguage == request.language)
        .toList();
    final activeLanguagePool = languageMatches.isNotEmpty
        ? languageMatches
        : links;
    if (languageMatches.isEmpty) {
      fallbackNotices.recordAudio(
        episodeNumber: episodeNumber,
        requested: request.language.toString(),
        selected: activeLanguagePool.first.audioLanguage.toString(),
      );
    }
    return _pickClosestResolution(
      activeLanguagePool,
      request.resolution,
      fallbackNotices,
      episodeNumber,
    );
  }

  animepahe.DownloadLink _pickClosestResolution(
    List<animepahe.DownloadLink> links,
    Resolution preferredResolution,
    FallbackNoticeCollector fallbackNotices,
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
      fallbackNotices.recordQuality(
        episodeNumber: episodeNumber,
        requested: preferredResolution.toString(),
        selected: chosen.resolution.toString(),
      );
    }
    return chosen;
  }
}
