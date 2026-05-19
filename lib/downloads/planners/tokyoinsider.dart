import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/target_path_planner.dart';
import 'package:senpwai/shared/net/download/download.dart';
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
  }) async {
    if (animeMatch == null) {
      throw const DownloadUserError(
        title: 'TokyoInsider unavailable',
        description: 'This anime does not currently have a TokyoInsider match.',
      );
    }

    final episodePages = await _source.fetchEpisodePages(
      animeUrl: animeMatch.url,
      animeTitle: animeMatch.title,
    );
    final pagesByEpisode = <int, tokyoinsider.EpisodePage>{};
    for (final page in episodePages) {
      pagesByEpisode.putIfAbsent(page.episodeNumber, () => page);
    }
    final missingEpisodes = [
      for (
        var episode = request.startEpisode;
        episode <= request.endEpisode;
        episode++
      )
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
      for (
        var episode = request.startEpisode;
        episode <= request.endEpisode;
        episode++
      )
        pagesByEpisode[episode]!,
    ];
    final jobs = <PreparedDownloadJob>[];
    for (var index = 0; index < selectedPages.length; index++) {
      final episodePage = selectedPages[index];
      final downloadLinks = await _source.fetchEpisodeDownloadLinks(
        episodePage: episodePage,
      );
      if (downloadLinks.isEmpty) {
        throw DownloadUserError(
          title: 'TokyoInsider link missing',
          description:
              'Episode ${episodePage.episodeNumber} has no download links on TokyoInsider.',
        );
      }

      final selectedLink = _selectLink(
        downloadLinks,
        request,
        notices,
        episodePage.episodeNumber,
      );
      final resolvedTarget = await Download.probeSingleFile(
        url: selectedLink.url,
      );
      final plannedTarget = _targetPlanner.planEpisodeFile(
        directory: request.downloadFolder,
        jobTitle: request.httpJobTitle,
        sourceFileName: selectedLink.filename,
        resolvedUrl: resolvedTarget.resolvedUrl,
        dedupeSuffix: index == 0 ? null : '(${index + 1})',
      );
      jobs.add(
        PreparedHttpDownloadJob(
          source: AnimeSource.tokyoinsider,
          animeTitle: request.anime.title.display,
          displayTitle: plannedTarget.fileName,
          destinationDirectory: plannedTarget.directory,
          totalBytes: resolvedTarget.sizeBytes,
          resolvedUrl: resolvedTarget.resolvedUrl,
          fileName: plannedTarget.fileName,
          episodeNumber: selectedLink.episodeNumber,
        ),
      );
    }

    return PreparedDownloadBatch(jobs: jobs, notices: notices);
  }

  tokyoinsider.EpisodeDownloadLink _selectLink(
    List<tokyoinsider.EpisodeDownloadLink> links,
    DownloadRequest request,
    List<DownloadNotice> notices,
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
}
