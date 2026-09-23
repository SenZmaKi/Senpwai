import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/sources/shared/shared.dart';

void main() {
  group('download model invariants', () {
    test('normalizes explicit episode numbers', () {
      final request = _request(episodeNumbers: [4, -1, 2, 4, 0, 3]);

      expect(request.episodeNumbers, [2, 3, 4]);
    });

    test('builds an inclusive episode range when no override is supplied', () {
      final request = _request(startEpisode: 3, endEpisode: 5);

      expect(request.episodeNumbers, [3, 4, 5]);
    });

    test('returns an empty range when start is after end', () {
      final request = _request(startEpisode: 5, endEpisode: 3);

      expect(request.episodeNumbers, isEmpty);
    });

    test('planning progress clamps invalid and overflowing values', () {
      expect(
        const DownloadPlanningProgress(
          completedEpisodes: 5,
          totalEpisodes: 0,
          activity: '',
        ).fraction,
        0,
      );
      expect(
        const DownloadPlanningProgress(
          completedEpisodes: 12,
          totalEpisodes: 10,
          activity: '',
        ).fraction,
        1,
      );
    });

    test('queue progress clamps corrupt byte counts', () {
      final item = _item(totalBytes: 100, downloadedBytes: 130);
      final negative = _item(totalBytes: 100, downloadedBytes: -20);
      final unknown = _item(totalBytes: 0, downloadedBytes: 10);

      expect(item.progress, 1);
      expect(negative.progress, 0);
      expect(unknown.progress, 0);
    });

    test('paused complete torrents remain in the seeding phase', () {
      expect(
        _item(
          source: AnimeSource.nyaa,
          status: DownloadQueueStatus.paused,
          totalBytes: 100,
          downloadedBytes: 100,
        ).isSeedingPhase,
        isTrue,
      );
      expect(
        _item(
          source: AnimeSource.animepahe,
          status: DownloadQueueStatus.paused,
          totalBytes: 100,
          downloadedBytes: 100,
        ).isSeedingPhase,
        isFalse,
      );
    });

    test('copyWith can explicitly clear download errors', () {
      final failed = _item(
        status: DownloadQueueStatus.failed,
        errorTitle: 'Network error',
        errorDescription: 'Timed out',
        errorCopyPayload: 'details',
      );

      final retried = failed.copyWith(
        status: DownloadQueueStatus.queued,
        clearError: true,
      );

      expect(retried.status, DownloadQueueStatus.queued);
      expect(retried.errorTitle, isNull);
      expect(retried.errorDescription, isNull);
      expect(retried.errorCopyPayload, isNull);
    });

    test('torrent file progress handles zero, partial, and excess bytes', () {
      const zero = TorrentFileProgress(
        path: 'zero.mkv',
        totalBytes: 0,
        downloadedBytes: 0,
        isActive: false,
      );
      const partial = TorrentFileProgress(
        path: 'partial.mkv',
        totalBytes: 4,
        downloadedBytes: 1,
        isActive: true,
      );
      const excess = TorrentFileProgress(
        path: 'excess.mkv',
        totalBytes: 4,
        downloadedBytes: 5,
        isActive: true,
      );

      expect(zero.progress, 0);
      expect(zero.isComplete, isFalse);
      expect(partial.progress, .25);
      expect(excess.progress, 1);
      expect(excess.isComplete, isTrue);
    });

    test('user errors include causes and stack traces in copy payloads', () {
      final error = DownloadUserError(
        title: 'Could not download',
        description: 'The source rejected the request.',
        cause: StateError('rejected'),
        stackTrace: StackTrace.fromString('line one'),
      );

      expect(error.toString(), contains('Could not download'));
      expect(error.copyPayload, contains('Bad state: rejected'));
      expect(error.copyPayload, contains('StateError'));
      expect(error.copyPayload, contains('line one'));
      expect(
        const DownloadUserError(title: 'x', description: 'y').copyPayload,
        isNull,
      );
    });

    test('only completed, failed, and cancelled queue states are terminal', () {
      for (final status in DownloadQueueStatus.values) {
        expect(
          status.isTerminal,
          {
            DownloadQueueStatus.completed,
            DownloadQueueStatus.failed,
            DownloadQueueStatus.cancelled,
          }.contains(status),
          reason: status.name,
        );
      }
    });
  });
}

DownloadRequest _request({
  int startEpisode = 1,
  int endEpisode = 12,
  List<int>? episodeNumbers,
}) => DownloadRequest(
  anime: const AnilistAnime(
    id: 1,
    title: AnilistTitle(romaji: 'Frieren'),
    genres: [],
  ),
  source: AnimeSource.animepahe,
  startEpisode: startEpisode,
  endEpisode: endEpisode,
  episodeNumbers: episodeNumbers,
  downloadFolder: '/anime',
  fileTitle: 'Frieren',
  resolution: Resolution.res1080p,
  language: Language.japanese,
);

DownloadQueueItem _item({
  AnimeSource source = AnimeSource.nyaa,
  DownloadQueueStatus status = DownloadQueueStatus.downloading,
  int totalBytes = 100,
  int downloadedBytes = 50,
  String? errorTitle,
  String? errorDescription,
  String? errorCopyPayload,
}) => DownloadQueueItem(
  id: 'item',
  batchId: 'batch',
  source: source,
  animeTitle: 'Frieren',
  displayTitle: 'Frieren E01',
  destinationDirectory: '/anime',
  status: status,
  totalBytes: totalBytes,
  downloadedBytes: downloadedBytes,
  bytesPerSecond: 0,
  createdAt: DateTime.utc(2026),
  errorTitle: errorTitle,
  errorDescription: errorDescription,
  errorCopyPayload: errorCopyPayload,
);
