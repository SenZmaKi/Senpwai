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

    void report({
      required DownloadPlanningPhase phase,
      required String activity,
      int? completedItems,
      int? totalItems,
    }) => onProgress?.call(
      DownloadPlanningProgress(
        phase: phase,
        completedItems: completedItems,
        totalItems: totalItems,
        activity: activity,
      ),
    );
    report(
      phase: DownloadPlanningPhase.discovering,
      activity: 'Finding episodes',
    );

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
      maxConcurrent: SourceConcurrencyLimits.instance.animePahe,
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
    var loadedOptions = 0;
    report(
      phase: DownloadPlanningPhase.loadingOptions,
      completedItems: loadedOptions,
      totalItems: selectedSessions.length,
      activity: 'Loading episode links',
    );
    final episodeLinks = await parallelMapOrdered(
      selectedSessions,
      maxConcurrent: SourceConcurrencyLimits.instance.animePahe,
      operation: (episodeSession) async {
        throwIfRequestScopeCancelled();
        final links = await _source.fetchDownloadLinks(
          animeTitle: animeMatch.title,
          animeSession: animeMatch.session,
          episodeSession: episodeSession,
        );
        throwIfRequestScopeCancelled();
        loadedOptions++;
        report(
          phase: DownloadPlanningPhase.loadingOptions,
          completedItems: loadedOptions,
          totalItems: selectedSessions.length,
          activity: 'Loaded episode ${episodeSession.number} links',
        );
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

    // Kwik form submissions lease isolated browser sessions. Keep that
    // renderer workload bounded independently from native media probes.
    final animePaheConcurrency = SourceConcurrencyLimits.instance.animePahe;
    final kwikConcurrency = SourceConcurrencyLimits.instance.kwik;
    final pipelineConcurrency = animePaheConcurrency > kwikConcurrency
        ? animePaheConcurrency
        : kwikConcurrency;
    final kwikLane = AsyncLimiter(kwikConcurrency);
    final probeLane = AsyncLimiter(animePaheConcurrency);
    final kwikBatch = _source.openKwikLinkResolverBatch();
    var remainingKwikLinks = selectedLinks.length;
    var checkedFiles = 0;
    report(
      phase: DownloadPlanningPhase.checkingFiles,
      completedItems: checkedFiles,
      totalItems: selectedLinks.length,
      activity: 'Checking download files',
    );
    late final List<PreparedDownloadJob> jobs;
    try {
      jobs =
          await parallelMapOrdered<animepahe.DownloadLink, PreparedDownloadJob>(
            selectedLinks,
            maxConcurrent: pipelineConcurrency,
            operation: (selectedLink) async {
              throwIfRequestScopeCancelled();
              final directLink = await kwikLane.run(() async {
                throwIfRequestScopeCancelled();
                final link = await _source.fetchDirectDownloadLink(
                  downloadLink: selectedLink,
                );
                throwIfRequestScopeCancelled();
                remainingKwikLinks--;
                if (remainingKwikLinks == 0) await kwikBatch.close();
                return link;
              });
              return probeLane.run(() async {
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
                checkedFiles++;
                report(
                  phase: DownloadPlanningPhase.checkingFiles,
                  completedItems: checkedFiles,
                  totalItems: selectedLinks.length,
                  activity: 'Checked episode ${directLink.episodeNumber}',
                );
                return job;
              });
            },
          );
    } finally {
      await kwikBatch.close();
    }

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
