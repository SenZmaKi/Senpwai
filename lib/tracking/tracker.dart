import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/anilist/client/unauthenticated.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/anitomy/anitomy.dart' as anitomy_parser;
import 'package:senpwai/downloads/filler_episodes.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/request_coordinator.dart';
import 'package:senpwai/downloads/source_resolver.dart';
import 'package:senpwai/downloads/target_path_planner.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/tracking/models.dart';

typedef TrackingEnqueueBatch =
    Future<EnqueuedDownloadsResult> Function(PreparedDownloadBatch batch);

final _log = Logger('senpwai.tracking.tracker');

class TrackingCheckResult {
  final List<TrackedAnime> trackedAnime;
  final int checkedCount;
  final int queuedBatchCount;
  final int queuedEpisodeCount;
  final List<TrackingEvent> events;

  const TrackingCheckResult({
    required this.trackedAnime,
    required this.checkedCount,
    required this.queuedBatchCount,
    required this.queuedEpisodeCount,
    this.events = const [],
  });
}

class AnimeTracker {
  final AnilistUnauthenticatedClient _anilistClient;
  final DownloadTargetPlanner _targetPlanner;
  final AnimeDownloadCoordinator _coordinator;
  final AnimeFillerService _fillerService;

  AnimeTracker({
    AnilistUnauthenticatedClient? anilistClient,
    DownloadTargetPlanner targetPlanner = const DownloadTargetPlanner(),
    AnimeDownloadCoordinator? coordinator,
    AnimeFillerService? fillerService,
  }) : _anilistClient = anilistClient ?? AnilistUnauthenticatedClient(),
       _targetPlanner = targetPlanner,
       _coordinator =
           coordinator ??
           AnimeDownloadCoordinator(targetPlanner: targetPlanner),
       _fillerService = fillerService ?? AnimeFillerService.instance;

  Future<TrackingCheckResult> check({
    required List<TrackedAnime> trackedAnime,
    required AppSettings settings,
    required DownloadManagerState downloadState,
    required TrackingEnqueueBatch enqueueBatch,
  }) async {
    final now = DateTime.now();
    var queuedBatchCount = 0;
    var queuedEpisodeCount = 0;
    var checkedCount = 0;
    final nextTrackedAnime = <TrackedAnime>[];
    final events = <TrackingEvent>[];

    for (final tracked in trackedAnime) {
      checkedCount += 1;
      try {
        final checked = await _checkOne(
          tracked: tracked,
          settings: settings,
          downloadState: downloadState,
          enqueueBatch: enqueueBatch,
          checkedAt: now,
        );
        final nextTracked = checked.tracked;
        if (nextTracked != null) {
          nextTrackedAnime.add(nextTracked);
        }
        queuedBatchCount += checked.queuedBatch ? 1 : 0;
        queuedEpisodeCount += checked.queuedEpisodes;
        events.addAll(checked.events);
      } on Object catch (error, stackTrace) {
        final title = tracked.animeSnapshot.title.display;
        _log.warningWithMetadata(
          'Tracked anime check failed',
          metadata: {
            'anilistId': tracked.anilistId,
            'title': title,
            'error': '$error',
            'stackTrace': '$stackTrace',
          },
        );
        events.add(
          TrackingEvent.create(
            kind: TrackingEventKind.failed,
            level: TrackingEventLevel.error,
            title: 'Tracking check failed',
            description: '$title: $error',
          ),
        );
        nextTrackedAnime.add(
          tracked.copyWith(
            lastCheckedAt: now,
            updatedAt: now,
            lastError: error.toString(),
          ),
        );
      }
    }

    return TrackingCheckResult(
      trackedAnime: nextTrackedAnime,
      checkedCount: checkedCount,
      queuedBatchCount: queuedBatchCount,
      queuedEpisodeCount: queuedEpisodeCount,
      events: events,
    );
  }

  Future<
    ({
      TrackedAnime? tracked,
      bool queuedBatch,
      int queuedEpisodes,
      List<TrackingEvent> events,
    })
  >
  _checkOne({
    required TrackedAnime tracked,
    required AppSettings settings,
    required DownloadManagerState downloadState,
    required TrackingEnqueueBatch enqueueBatch,
    required DateTime checkedAt,
  }) async {
    final freshAnime =
        await _anilistClient.getAnimeById(tracked.anilistId) ??
        tracked.animeSnapshot;
    final availableEpisodes = availableEpisodesForTracking(freshAnime);
    final havedEpisode = await _lastHavedEpisode(
      tracked: tracked,
      downloadState: downloadState,
    );

    if (availableEpisodes <= havedEpisode) {
      if (freshAnime.status == AnilistAiringStatus.finished) {
        return (
          tracked: null,
          queuedBatch: false,
          queuedEpisodes: 0,
          events: [_finishedTrackingEvent(freshAnime)],
        );
      }
      return (
        tracked: _markChecked(tracked, anime: freshAnime, checkedAt: checkedAt),
        queuedBatch: false,
        queuedEpisodes: 0,
        events: const <TrackingEvent>[],
      );
    }

    final startEpisode = havedEpisode + 1;
    final endEpisode = availableEpisodes;
    final fillerEpisodes = settings.downloads.skipFillers
        ? await _fillerService.getFillerEpisodes(
            anime: freshAnime,
            episodeCount: availableEpisodes,
          )
        : const <int>{};
    final requestedEpisodes = [
      for (var episode = startEpisode; episode <= endEpisode; episode++)
        if (!fillerEpisodes.contains(episode)) episode,
    ];
    if (requestedEpisodes.isEmpty) {
      if (freshAnime.status == AnilistAiringStatus.finished) {
        return (
          tracked: null,
          queuedBatch: false,
          queuedEpisodes: 0,
          events: [_finishedTrackingEvent(freshAnime)],
        );
      }
      return (
        tracked: _markChecked(tracked, anime: freshAnime, checkedAt: checkedAt),
        queuedBatch: false,
        queuedEpisodes: 0,
        events: const <TrackingEvent>[],
      );
    }

    final resolver = DownloadSourceResolver(settings: settings.sources);
    final matches = await resolver.resolveAll(freshAnime);
    final source = resolver.selectPreferredSource(
      matches: matches,
      sourceSelectedByUser: tracked.sourceSelectedByUser,
      selectedSource: tracked.preferredSource,
    );
    if (source == null) {
      throw StateError('No enabled source is available for this anime.');
    }

    final folder = tracked.downloadFolder.trim().isNotEmpty
        ? tracked.downloadFolder
        : (await _targetPlanner.resolveAnimeLocation(
            anime: freshAnime,
            downloadRoots: settings.downloads.effectiveRootDirectories,
            customAnimeFolders: settings.downloads.customAnimeFolders,
          )).episodeDirectory;
    final fileIdentity = DownloadTargetPlanner.fileIdentityFor(freshAnime);
    final batch = await _coordinator.plan(
      request: DownloadRequest(
        anime: freshAnime,
        source: source,
        startEpisode: startEpisode,
        endEpisode: endEpisode,
        episodeNumbers: requestedEpisodes,
        downloadFolder: folder,
        fileTitle: fileIdentity.fileTitle,
        fileSeasonNumber: fileIdentity.seasonNumber,
        resolution: tracked.resolution,
        language: tracked.language,
      ),
      animepaheMatch: matches.animepaheMatch.result?.result,
      tokyoinsiderMatch: matches.tokyoinsiderMatch.result?.result,
    );
    if (batch.requiresUserInteraction) {
      final description = _nyaaReviewDescription(
        freshAnime.title.display,
        batch,
      );
      return (
        tracked: tracked.copyWith(
          animeSnapshot: freshAnime,
          lastCheckedAt: checkedAt,
          updatedAt: checkedAt,
          lastError: description,
        ),
        queuedBatch: false,
        queuedEpisodes: 0,
        events: [
          TrackingEvent.create(
            kind: TrackingEventKind.reviewNeeded,
            level: TrackingEventLevel.warning,
            title: 'Torrent review needed',
            description: description,
          ),
        ],
      );
    }
    if (batch.jobs.isEmpty) {
      throw StateError('No downloadable episodes were found.');
    }

    final result = await enqueueBatch(batch);
    if (result.queuedCount <= 0) {
      throw StateError('The tracker prepared episodes but none were queued.');
    }

    final batchId = result.batchId;
    final title = freshAnime.title.display;
    final episodeLabel = requestedEpisodes.length == 1 ? 'episode' : 'episodes';
    final events = <TrackingEvent>[
      TrackingEvent.create(
        kind: TrackingEventKind.queued,
        level: TrackingEventLevel.info,
        title: 'Queued new $episodeLabel',
        description:
            '$title $episodeLabel ${_episodeListText(requestedEpisodes)} were added to downloads.',
      ),
      ..._noticeEvents(title, batch.notices),
    ];
    return (
      tracked: tracked.copyWith(
        animeSnapshot: freshAnime,
        preferredSource: source,
        sourceSelectedByUser: tracked.sourceSelectedByUser,
        downloadFolder: folder,
        lastCheckedAt: checkedAt,
        updatedAt: checkedAt,
        completionBatchId: freshAnime.status == AnilistAiringStatus.finished
            ? batchId
            : null,
        clearCompletionBatchId:
            freshAnime.status != AnilistAiringStatus.finished ||
            batchId == null,
        clearLastError: true,
      ),
      queuedBatch: true,
      queuedEpisodes: requestedEpisodes.length,
      events: events,
    );
  }

  TrackedAnime _markChecked(
    TrackedAnime tracked, {
    required AnilistAnime anime,
    required DateTime checkedAt,
  }) {
    return tracked.copyWith(
      animeSnapshot: anime,
      lastCheckedAt: checkedAt,
      updatedAt: checkedAt,
      clearLastError: true,
    );
  }
}

TrackingEvent _finishedTrackingEvent(
  AnilistAnimeBase anime,
) => TrackingEvent.create(
  kind: TrackingEventKind.finishedTracking,
  level: TrackingEventLevel.info,
  title: 'Finished tracking',
  description:
      '${anime.title.display} completed and was removed from tracked anime.',
);

String _episodeListText(List<int> episodes) {
  if (episodes.isEmpty) return '';
  final ranges = <String>[];
  var rangeStart = episodes.first;
  var previous = episodes.first;
  for (final episode in episodes.skip(1)) {
    if (episode == previous + 1) {
      previous = episode;
      continue;
    }
    ranges.add(_episodeRangeText(rangeStart, previous));
    rangeStart = episode;
    previous = episode;
  }
  ranges.add(_episodeRangeText(rangeStart, previous));
  return ranges.join(', ');
}

String _episodeRangeText(int start, int end) =>
    start == end ? '$start' : '$start-$end';

Future<int> _lastHavedEpisode({
  required TrackedAnime tracked,
  required DownloadManagerState downloadState,
}) async {
  final folder = tracked.downloadFolder.trim();
  final paths = <String>[];
  if (folder.isNotEmpty) {
    final directory = Directory(folder);
    if (await directory.exists()) {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File && _looksLikeVideoFile(entity.path)) {
          paths.add(entity.path);
        }
      }
    }
  }
  paths.addAll(_inFlightPaths(tracked, downloadState));
  var maxEpisode = 0;
  for (final filePath in paths) {
    final episode = anitomy_parser
        .parseFilename(path.basename(filePath))
        .episode;
    if (episode != null && episode > maxEpisode) {
      maxEpisode = episode;
    }
  }
  return maxEpisode;
}

Iterable<String> _inFlightPaths(
  TrackedAnime tracked,
  DownloadManagerState downloadState,
) sync* {
  final folder = path.normalize(tracked.downloadFolder);
  for (final item in downloadState.items) {
    if (item.status == DownloadQueueStatus.failed ||
        item.status == DownloadQueueStatus.cancelled) {
      continue;
    }
    final itemDirectory = path.normalize(item.destinationDirectory);
    final sameDirectory = folder.isNotEmpty && itemDirectory == folder;
    final sameTitle = item.animeTitle == tracked.animeSnapshot.title.display;
    if (!sameDirectory && !sameTitle) continue;
    if (item.filePaths.isEmpty) {
      yield item.displayTitle;
      continue;
    }
    yield* item.filePaths;
  }
}

bool _looksLikeVideoFile(String filePath) {
  const extensions = {
    '.avi',
    '.flv',
    '.m2ts',
    '.m4v',
    '.mkv',
    '.mov',
    '.mp4',
    '.mpeg',
    '.mpg',
    '.ogm',
    '.ogv',
    '.ts',
    '.webm',
    '.wmv',
  };
  return extensions.contains(path.extension(filePath).toLowerCase());
}

String _nyaaReviewDescription(String title, PreparedDownloadBatch batch) {
  final episodes =
      batch.nyaaEpisodeIssues
          .map((issue) => issue.episodeNumber)
          .toSet()
          .toList()
        ..sort();
  final episodeText = episodes.isEmpty
      ? 'one or more episodes'
      : 'episode${episodes.length == 1 ? '' : 's'} ${episodes.join(', ')}';
  return '$title needs manual torrent selection for $episodeText.';
}

Iterable<TrackingEvent> _noticeEvents(
  String title,
  Iterable<DownloadNotice> notices,
) sync* {
  for (final notice in notices) {
    yield TrackingEvent.create(
      kind: TrackingEventKind.warning,
      level: switch (notice.level) {
        DownloadNoticeLevel.info => TrackingEventLevel.info,
        DownloadNoticeLevel.warning => TrackingEventLevel.warning,
      },
      title: notice.title,
      description: [
        title,
        if (notice.description != null) notice.description!,
      ].join(': '),
    );
  }
}

int availableEpisodesForTracking(AnilistAnimeBase anime) {
  final nextEpisodeNumber = anime.episode;
  if (nextEpisodeNumber != null) {
    var airedEpisodes = nextEpisodeNumber - 1;
    if (airedEpisodes < 0) airedEpisodes = 0;
    final totalEpisodes = anime.episodes;
    if (totalEpisodes != null && airedEpisodes > totalEpisodes) {
      airedEpisodes = totalEpisodes;
    }
    return airedEpisodes;
  }
  if (anime.status == AnilistAiringStatus.notYetReleased) {
    return 0;
  }
  return anime.episodes ?? 1;
}

AnilistAnime animeSnapshotFromBase(AnilistAnimeBase anime) => AnilistAnime(
  id: anime.id,
  title: anime.title,
  format: anime.format,
  season: anime.season,
  seasonYear: anime.seasonYear,
  episodes: anime.episodes,
  episode: anime.episode,
  nextEpisodeAiring: anime.nextEpisodeAiring,
  status: anime.status,
  description: anime.description,
  genres: anime.genres,
  averageScore: anime.averageScore,
  coverImage: anime.coverImage,
  bannerImage: anime.bannerImage,
  startDate: anime.startDate,
  endDate: anime.endDate,
  isFavourite: anime.isFavourite,
  isAdult: anime.isAdult,
);
