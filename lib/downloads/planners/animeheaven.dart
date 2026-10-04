import 'package:senpwai/anitomy/anitomy.dart' as anitomy_parser;
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/target_path_planner.dart';
import 'package:senpwai/shared/net/download/download.dart';
import 'package:senpwai/shared/net/request_cancellation_scope.dart';
import 'package:senpwai/shared/parallel.dart';
import 'package:senpwai/sources/animeheaven.dart' as animeheaven;
import 'package:senpwai/sources/shared/shared.dart';

/// AnimeHeaven hosts a single subbed file per episode, so quality and audio
/// preferences can only be reported, never selected.
class AnimeHeavenDownloadPlanner {
  final animeheaven.Source _source;
  final DownloadTargetPlanner _targetPlanner;

  AnimeHeavenDownloadPlanner({
    animeheaven.Source? source,
    DownloadTargetPlanner? targetPlanner,
  }) : _source = source ?? animeheaven.Source.getInstance(),
       _targetPlanner = targetPlanner ?? const DownloadTargetPlanner();

  Future<PreparedDownloadBatch> plan({
    required DownloadRequest request,
    required animeheaven.AnimeResult? animeMatch,
    DownloadPlanningProgressCallback? onProgress,
  }) async {
    final requestedEpisodes = request.episodeNumbers;
    if (requestedEpisodes.isEmpty) {
      return const PreparedDownloadBatch(jobs: []);
    }
    if (animeMatch == null) {
      throw const DownloadUserError(
        title: 'AnimeHeaven unavailable',
        description: 'This anime does not currently have an AnimeHeaven match.',
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

    final episodePages = await _source.fetchEpisodePages(
      animeUrl: animeMatch.url,
      animeTitle: animeMatch.title,
    );
    throwIfRequestScopeCancelled();
    final pagesByEpisode = <int, animeheaven.EpisodePage>{};
    for (final page in episodePages) {
      pagesByEpisode.putIfAbsent(page.episodeNumber, () => page);
    }
    final missingEpisodes = [
      for (final episode in requestedEpisodes)
        if (!pagesByEpisode.containsKey(episode)) episode,
    ];
    final selectedPages = [
      for (final episode in requestedEpisodes)
        if (pagesByEpisode[episode] case final page?) page,
    ];
    if (selectedPages.isEmpty) {
      throw const DownloadUserError(
        title: 'No episodes found',
        description:
            'AnimeHeaven could not find any episodes in the requested range.',
      );
    }

    final notices = <DownloadNotice>[
      if (request.language != Language.japanese)
        DownloadNotice(
          level: DownloadNoticeLevel.warning,
          title: 'Audio fallback',
          description:
              'AnimeHeaven only provides subbed episodes; using Japanese audio instead of ${request.language}.',
        ),
    ];
    final fallbackResolutions = <Resolution>{};
    var preparedEpisodes = 0;
    report(
      phase: DownloadPlanningPhase.checkingFiles,
      completedItems: preparedEpisodes,
      totalItems: selectedPages.length,
      activity: 'Checking download files',
    );
    final jobs =
        await parallelMapOrdered<animeheaven.EpisodePage, PreparedDownloadJob>(
          selectedPages,
          maxConcurrent: SourceConcurrencyLimits.instance.animeHeaven,
          operation: (episodePage) async {
            throwIfRequestScopeCancelled();
            final downloadUrl = await _source.fetchDownloadUrl(
              episodePage: episodePage,
            );
            throwIfRequestScopeCancelled();
            final resolvedTarget = await Download.probeSingleFile(
              url: downloadUrl,
            );
            throwIfRequestScopeCancelled();
            final sourceFileName = resolvedTarget.suggestedFileName ?? '';
            final resolution =
                anitomy_parser.parseFilename(sourceFileName).resolution ??
                parseResolution(sourceFileName);
            if (resolution != null && resolution != request.resolution) {
              fallbackResolutions.add(resolution);
            }
            final plannedTarget = _targetPlanner.planEpisodeFile(
              directory: request.downloadFolder,
              jobTitle: request.fileTitle,
              episodeNumber: episodePage.episodeNumber,
              seasonNumber: request.fileSeasonNumber,
              sourceFileName: sourceFileName,
              resolvedUrl: resolvedTarget.resolvedUrl,
              suggestedFileName: resolvedTarget.suggestedFileName,
              contentType: resolvedTarget.contentType,
            );
            final job = PreparedHttpDownloadJob(
              source: AnimeSource.animeheaven,
              animeTitle: request.anime.title.display,
              displayTitle: plannedTarget.fileName,
              destinationDirectory: plannedTarget.directory,
              totalBytes: resolvedTarget.sizeBytes,
              resolvedUrl: resolvedTarget.resolvedUrl,
              fileName: plannedTarget.fileName,
              episodeNumber: episodePage.episodeNumber,
            );
            preparedEpisodes++;
            report(
              phase: DownloadPlanningPhase.checkingFiles,
              completedItems: preparedEpisodes,
              totalItems: selectedPages.length,
              activity: 'Checked episode ${episodePage.episodeNumber}',
            );
            return job;
          },
        );

    if (fallbackResolutions.isNotEmpty) {
      notices.add(
        DownloadNotice(
          level: DownloadNoticeLevel.warning,
          title: 'Quality fallback',
          description:
              'AnimeHeaven does not offer ${request.resolution}; using ${fallbackResolutions.join(', ')}.',
        ),
      );
    }
    return PreparedDownloadBatch(
      jobs: jobs,
      notices: notices,
      unavailableEpisodeNumbers: missingEpisodes,
    );
  }
}
