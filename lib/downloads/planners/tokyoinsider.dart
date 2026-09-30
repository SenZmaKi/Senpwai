import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/planners/fallback_notice_collector.dart';
import 'package:senpwai/downloads/target_path_planner.dart';
import 'package:senpwai/shared/net/download/download.dart';
import 'package:senpwai/shared/net/request_cancellation_scope.dart';
import 'package:senpwai/shared/parallel.dart';
import 'package:senpwai/sources/tokyoinsider.dart' as tokyoinsider;

class TokyoInsiderDownloadPlanner {
  final tokyoinsider.Source _source;
  final DownloadTargetPlanner _targetPlanner;

  TokyoInsiderDownloadPlanner({
    tokyoinsider.Source? source,
    DownloadTargetPlanner? targetPlanner,
  }) : _source = source ?? tokyoinsider.Source.getInstance(),
       _targetPlanner = targetPlanner ?? const DownloadTargetPlanner();

  Future<PreparedDownloadBatch> plan({
    required DownloadRequest request,
    required tokyoinsider.AnimeResult? animeMatch,
    DownloadPlanningProgressCallback? onProgress,
  }) async {
    final requestedEpisodes = request.episodeNumbers;
    if (requestedEpisodes.isEmpty) {
      return const PreparedDownloadBatch(jobs: []);
    }
    if (animeMatch == null) {
      throw const DownloadUserError(
        title: 'TokyoInsider unavailable',
        description: 'This anime does not currently have a TokyoInsider match.',
      );
    }

    final totalEpisodes = requestedEpisodes.length;
    var completedEpisodes = 0;
    var completedSteps = 0;
    var totalSteps = totalEpisodes * 2;
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

    final episodePages = await _source.fetchEpisodePages(
      animeUrl: animeMatch.url,
      animeTitle: animeMatch.title,
    );
    throwIfRequestScopeCancelled();
    final pagesByEpisode = <int, tokyoinsider.EpisodePage>{};
    for (final page in episodePages) {
      pagesByEpisode.putIfAbsent(page.episodeNumber, () => page);
    }
    final missingEpisodes = [
      for (final episode in requestedEpisodes)
        if (!pagesByEpisode.containsKey(episode)) episode,
    ];
    if (missingEpisodes.length == requestedEpisodes.length) {
      throw DownloadUserError(
        title: 'No episodes found',
        description:
            'TokyoInsider could not find any episodes in the requested range.',
      );
    }

    final notices = <DownloadNotice>[];
    final fallbackNotices = FallbackNoticeCollector(
      sourceName: AnimeSource.tokyoinsider.label,
    );
    final selectedPages = [
      for (final episode in requestedEpisodes)
        if (pagesByEpisode.containsKey(episode)) pagesByEpisode[episode]!,
    ];
    totalSteps = selectedPages.length * 2;
    report('Loading episode links');
    final episodeLinks = await parallelMapOrdered(
      selectedPages,
      maxConcurrent: SourceConcurrencyLimits.instance.tokyoInsider,
      operation: (episodePage) async {
        throwIfRequestScopeCancelled();
        final links = await _source.fetchEpisodeDownloadLinks(
          episodePage: episodePage,
        );
        throwIfRequestScopeCancelled();
        completedSteps++;
        report('Loaded episode ${episodePage.episodeNumber} links');
        return (episodePage: episodePage, links: links);
      },
    );

    final selectedLinks = <tokyoinsider.EpisodeDownloadLink>[];
    for (final (:episodePage, :links) in episodeLinks) {
      final downloadLinks = links;
      if (downloadLinks.isEmpty) {
        missingEpisodes.add(episodePage.episodeNumber);
        completedSteps++;
        report('Episode ${episodePage.episodeNumber} is unavailable');
        continue;
      }

      selectedLinks.add(
        _selectLink(
          downloadLinks,
          request,
          fallbackNotices,
          episodePage.episodeNumber,
        ),
      );
    }

    report('Checking download files');
    final jobs =
        await parallelMapOrdered<
          tokyoinsider.EpisodeDownloadLink,
          PreparedDownloadJob
        >(
          selectedLinks,
          maxConcurrent: SourceConcurrencyLimits.instance.tokyoInsider,
          operation: (selectedLink) async {
            throwIfRequestScopeCancelled();
            final resolvedTarget = await Download.probeSingleFile(
              url: selectedLink.url,
            );
            throwIfRequestScopeCancelled();
            final plannedTarget = _targetPlanner.planEpisodeFile(
              directory: request.downloadFolder,
              jobTitle: request.fileTitle,
              episodeNumber: selectedLink.episodeNumber,
              seasonNumber: request.fileSeasonNumber,
              sourceFileName: selectedLink.filename,
              resolvedUrl: resolvedTarget.resolvedUrl,
              suggestedFileName: resolvedTarget.suggestedFileName,
              contentType: resolvedTarget.contentType,
            );
            final job = PreparedHttpDownloadJob(
              source: AnimeSource.tokyoinsider,
              animeTitle: request.anime.title.display,
              displayTitle: plannedTarget.fileName,
              destinationDirectory: plannedTarget.directory,
              totalBytes: resolvedTarget.sizeBytes,
              resolvedUrl: resolvedTarget.resolvedUrl,
              fileName: plannedTarget.fileName,
              episodeNumber: selectedLink.episodeNumber,
            );
            completedSteps++;
            completedEpisodes++;
            report('Prepared episode ${selectedLink.episodeNumber}');
            return job;
          },
        );

    missingEpisodes.sort();
    notices.addAll(fallbackNotices.build());
    if (jobs.isEmpty) {
      throw DownloadUserError(
        title: 'No episodes found',
        description:
            'TokyoInsider could not find any episodes in the requested range.',
      );
    }
    return PreparedDownloadBatch(
      jobs: jobs,
      notices: notices,
      unavailableEpisodeNumbers: missingEpisodes,
    );
  }

  tokyoinsider.EpisodeDownloadLink _selectLink(
    List<tokyoinsider.EpisodeDownloadLink> links,
    DownloadRequest request,
    FallbackNoticeCollector fallbackNotices,
    int episodeNumber,
  ) {
    final exactLanguage = links
        .where((link) => link.language == request.language)
        .toList();
    final unknownLanguage = links
        .where((link) => link.language == null)
        .toList();
    final languagePool = exactLanguage.isNotEmpty
        ? exactLanguage
        : (unknownLanguage.isNotEmpty ? unknownLanguage : links);
    if (exactLanguage.isEmpty) {
      fallbackNotices.recordAudio(
        episodeNumber: episodeNumber,
        requested: request.language.toString(),
        selected: languagePool.first.language?.toString() ?? 'unknown',
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
      fallbackNotices.recordQuality(
        episodeNumber: episodeNumber,
        requested: request.resolution.toString(),
        selected: chosen.resolution.toString(),
      );
    }
    return chosen;
  }
}
