import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/tracking/models.dart';
import 'package:senpwai/tracking/tracker.dart';

void main() {
  final checkedAt = DateTime.utc(2026, 9, 24, 8, 30);

  group('availableEpisodesForTracking', () {
    test('uses the episodes which aired before the next episode', () {
      expect(availableEpisodesForTracking(_anime(episode: 4, episodes: 12)), 3);
    });

    test('clamps AniList next-episode data to the series total', () {
      expect(
        availableEpisodesForTracking(_anime(episode: 15, episodes: 12)),
        12,
      );
    });

    test('does not expose unreleased episodes', () {
      expect(
        availableEpisodesForTracking(
          _anime(status: AnilistAiringStatus.notYetReleased, episodes: 12),
        ),
        0,
      );
    });
  });

  test(
    'marks an airing title checked when there are no new episodes',
    () async {
      final tracker = AnimeTracker(
        now: () => checkedAt,
        loadAnime: (_) async => _anime(episode: 3, episodes: 12),
        resolveLastEpisode: (_, _) async => 2,
        prepareBatch: _unexpectedBatchPreparation,
      );

      final result = await _check(tracker, [_tracked()]);

      expect(result.checkedCount, 1);
      expect(result.queuedEpisodeCount, 0);
      expect(result.events, isEmpty);
      expect(result.trackedAnime.single.lastCheckedAt, checkedAt);
      expect(result.trackedAnime.single.updatedAt, checkedAt);
    },
  );

  test('removes a finished title after every episode is present', () async {
    final tracker = AnimeTracker(
      now: () => checkedAt,
      loadAnime: (_) async =>
          _anime(episodes: 12, status: AnilistAiringStatus.finished),
      resolveLastEpisode: (_, _) async => 12,
      prepareBatch: _unexpectedBatchPreparation,
    );

    final result = await _check(tracker, [_tracked()]);

    expect(result.trackedAnime, isEmpty);
    expect(result.events.single.kind, TrackingEventKind.finishedTracking);
  });

  test('filters fillers and records the queued completion batch', () async {
    List<int>? preparedEpisodes;
    int? preparedStart;
    int? preparedEnd;
    final tracker = AnimeTracker(
      now: () => checkedAt,
      loadAnime: (_) async =>
          _anime(episodes: 4, status: AnilistAiringStatus.finished),
      resolveLastEpisode: (_, _) async => 1,
      loadFillers: (_, _) async => {2, 4},
      prepareBatch: (tracked, anime, settings, start, end, episodes) async {
        preparedStart = start;
        preparedEnd = end;
        preparedEpisodes = episodes;
        return TrackingPreparedBatch(
          batch: PreparedDownloadBatch(jobs: [_job()]),
          source: AnimeSource.animepahe,
          downloadFolder: 'D:/Anime/Test',
        );
      },
    );

    final result = await _check(
      tracker,
      [_tracked(lastError: 'old failure')],
      settings: const AppSettings(
        downloads: DownloadPreferences(skipFillers: true),
      ),
      enqueueBatch: (_) async => const EnqueuedDownloadsResult(
        queuedCount: 1,
        batchId: 'completion-batch',
      ),
    );

    expect(preparedEpisodes, [3]);
    expect(preparedStart, 2);
    expect(preparedEnd, 4);
    expect(result.queuedBatchCount, 1);
    expect(result.queuedEpisodeCount, 1);
    expect(result.events.single.kind, TrackingEventKind.queued);
    expect(result.events.single.description, contains('episode 3'));
    expect(result.trackedAnime.single.completionBatchId, 'completion-batch');
    expect(result.trackedAnime.single.lastError, isNull);
    expect(result.trackedAnime.single.downloadFolder, 'D:/Anime/Test');
  });

  test('keeps a title and emits review-needed without enqueueing', () async {
    var enqueueCalled = false;
    final tracker = AnimeTracker(
      now: () => checkedAt,
      loadAnime: (_) async => _anime(episode: 3, episodes: 12),
      resolveLastEpisode: (_, _) async => 0,
      prepareBatch: (tracked, anime, settings, start, end, episodes) async =>
          const TrackingPreparedBatch(
            batch: PreparedDownloadBatch(
              jobs: [],
              unavailableEpisodeNumbers: [1],
            ),
            source: AnimeSource.nyaa,
            downloadFolder: 'D:/Anime/Test',
          ),
    );

    final result = await _check(
      tracker,
      [_tracked()],
      enqueueBatch: (_) async {
        enqueueCalled = true;
        return const EnqueuedDownloadsResult(queuedCount: 1);
      },
    );

    expect(enqueueCalled, isFalse);
    expect(result.trackedAnime, hasLength(1));
    expect(result.trackedAnime.single.lastError, contains('manual'));
    expect(result.events.single.kind, TrackingEventKind.reviewNeeded);
  });

  test('isolates one title failure and continues checking the rest', () async {
    final tracker = AnimeTracker(
      now: () => checkedAt,
      loadAnime: (id) async {
        if (id == 1) throw StateError('AniList unavailable');
        return _anime(id: id, episode: 2, episodes: 12);
      },
      resolveLastEpisode: (_, _) async => 1,
      prepareBatch: _unexpectedBatchPreparation,
    );

    final result = await _check(tracker, [_tracked(), _tracked(id: 2)]);

    expect(result.checkedCount, 2);
    expect(result.trackedAnime, hasLength(2));
    expect(
      result.trackedAnime.first.lastError,
      contains('AniList unavailable'),
    );
    expect(result.trackedAnime.last.lastError, isNull);
    expect(result.events.single.kind, TrackingEventKind.failed);
  });
}

Future<TrackingCheckResult> _check(
  AnimeTracker tracker,
  List<TrackedAnime> trackedAnime, {
  AppSettings settings = const AppSettings(),
  TrackingEnqueueBatch? enqueueBatch,
}) => tracker.check(
  trackedAnime: trackedAnime,
  settings: settings,
  downloadState: const DownloadManagerState(),
  enqueueBatch:
      enqueueBatch ??
      (_) async => const EnqueuedDownloadsResult(queuedCount: 1),
);

Future<TrackingPreparedBatch> _unexpectedBatchPreparation(
  TrackedAnime tracked,
  AnilistAnime anime,
  AppSettings settings,
  int startEpisode,
  int endEpisode,
  List<int> episodes,
) => throw StateError('Batch preparation should not be reached.');

TrackedAnime _tracked({int id = 1, String? lastError}) => TrackedAnime(
  anilistId: id,
  animeSnapshot: _anime(id: id, episode: 2, episodes: 12),
  downloadFolder: 'D:/Anime/Test',
  resolution: Resolution.res1080p,
  language: Language.japanese,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  lastError: lastError,
);

AnilistAnime _anime({
  int id = 1,
  int? episode,
  int? episodes,
  AnilistAiringStatus? status = AnilistAiringStatus.releasing,
}) => AnilistAnime(
  id: id,
  title: AnilistTitle(romaji: 'Test $id'),
  episodes: episodes,
  episode: episode,
  status: status,
  genres: const [],
);

PreparedHttpDownloadJob _job() => const PreparedHttpDownloadJob(
  source: AnimeSource.animepahe,
  animeTitle: 'Test 1',
  displayTitle: 'Test 1 - 02.mkv',
  destinationDirectory: 'D:/Anime/Test',
  totalBytes: 10,
  resolvedUrl: 'https://example.com/2',
  fileName: 'Test 1 - 02.mkv',
  episodeNumber: 2,
);
