import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/runtime_codec.dart';
import 'package:senpwai/settings/settings.dart';

void main() {
  group('DownloadRuntimeCodec', () {
    test('round trips a complete manager state', () {
      final createdAt = DateTime.utc(2026, 9, 23, 12, 30);
      final state = DownloadManagerState(
        activeBatchId: 'batch-1',
        batches: [
          DownloadBatchQueue(
            id: 'batch-1',
            title: 'Frieren',
            source: AnimeSource.nyaa,
            createdAt: createdAt,
            itemIds: const ['item-1'],
          ),
        ],
        items: [
          DownloadQueueItem(
            id: 'item-1',
            batchId: 'batch-1',
            source: AnimeSource.nyaa,
            animeTitle: 'Frieren',
            displayTitle: 'Frieren E01',
            destinationDirectory: 'C:/Anime/Frieren',
            status: DownloadQueueStatus.seeding,
            totalBytes: 200,
            downloadedBytes: 200,
            bytesPerSecond: 12.5,
            createdAt: createdAt,
            filePaths: const ['C:/Anime/Frieren/Frieren E01.mkv'],
            torrentStats: const TorrentLiveStats(
              uploadBytesPerSecond: 4.5,
              numSeeds: 2,
              numPeers: 3,
              listSeeds: 8,
              listPeers: 13,
              totalUploaded: 90,
            ),
            torrentFiles: const [
              TorrentFileProgress(
                path: 'Frieren E01.mkv',
                totalBytes: 200,
                downloadedBytes: 200,
                isActive: true,
              ),
            ],
            seedingTargetReached: true,
          ),
        ],
      );

      final decoded = DownloadRuntimeCodec.decodeState(
        jsonDecode(jsonEncode(DownloadRuntimeCodec.encodeState(state))) as Map,
      );

      expect(decoded.activeBatchId, 'batch-1');
      expect(decoded.batches.single.itemIds, ['item-1']);
      final item = decoded.items.single;
      expect(item.status, DownloadQueueStatus.seeding);
      expect(item.createdAt, createdAt);
      expect(item.filePaths, state.items.single.filePaths);
      expect(item.torrentStats?.uploadBytesPerSecond, 4.5);
      expect(item.torrentStats?.totalUploaded, 90);
      expect(item.torrentFiles.single.isComplete, isTrue);
      expect(item.seedingTargetReached, isTrue);
    });

    test('decodes missing and future values with safe defaults', () {
      final item = DownloadRuntimeCodec.decodeItem({
        'id': 'item',
        'batchId': 'batch',
        'source': 'futureSource',
        'status': 'futureStatus',
        'totalBytes': 'not-an-int',
        'bytesPerSecond': 4,
        'filePaths': [1, 'valid.mkv'],
        'torrentFiles': 'not-a-list',
      });

      expect(item.source, AnimeSource.nyaa);
      expect(item.status, DownloadQueueStatus.queued);
      expect(item.totalBytes, 0);
      expect(item.bytesPerSecond, 4.0);
      expect(item.filePaths, ['valid.mkv']);
      expect(item.torrentFiles, isEmpty);
      expect(item.torrentStats, isNull);
    });

    test('round trips HTTP jobs including headers and nullable episode', () {
      const job = PreparedHttpDownloadJob(
        source: AnimeSource.animepahe,
        animeTitle: 'Frieren',
        displayTitle: 'Frieren E02',
        destinationDirectory: '/anime/frieren',
        totalBytes: 123,
        resolvedUrl: 'https://cdn.example/frieren-2.mp4',
        fileName: 'Frieren E02.mp4',
        episodeNumber: 2,
        headers: {'Referer': 'https://anime.example', 'attempt': 2},
      );

      final decoded =
          DownloadRuntimeCodec.decodePreparedJob(
                DownloadRuntimeCodec.encodePreparedJob(job),
              )
              as PreparedHttpDownloadJob;

      expect(decoded.source, AnimeSource.animepahe);
      expect(decoded.episodeNumber, 2);
      expect(decoded.headers, job.headers);
      expect(decoded.targetFilePath, endsWith('Frieren E02.mp4'));
    });

    test('round trips torrent jobs through JSON-compatible transport', () {
      final job = PreparedTorrentDownloadJob(
        source: AnimeSource.nyaa,
        animeTitle: 'Frieren',
        displayTitle: 'Frieren batch',
        destinationDirectory: '/anime/frieren',
        totalBytes: 999,
        torrentData: Uint8List.fromList([0, 1, 127, 255]),
        torrentName: 'frieren.torrent',
        selectedFileIndices: const [1, 3],
        selectedFilePaths: const ['01.mkv', '03.mkv'],
        renamedFilePaths: const {1: 'Frieren E01.mkv', 3: 'Frieren E03.mkv'},
      );
      final wire =
          jsonDecode(jsonEncode(DownloadRuntimeCodec.encodePreparedJob(job)))
              as Map;

      final decoded =
          DownloadRuntimeCodec.decodePreparedJob(wire)
              as PreparedTorrentDownloadJob;

      expect(decoded.torrentData, job.torrentData);
      expect(decoded.selectedFileIndices, [1, 3]);
      expect(decoded.renamedFilePaths, job.renamedFilePaths);
    });

    test('round trips prepared batches, notices, and enqueue results', () {
      const notice = DownloadNotice(
        level: DownloadNoticeLevel.warning,
        title: 'Missing episode',
        description: 'Episode 4 was unavailable.',
      );
      const batch = PreparedDownloadBatch(
        jobs: [],
        notices: [notice],
        unavailableEpisodeNumbers: [4, 7],
      );

      final decodedBatch = DownloadRuntimeCodec.decodePreparedBatch(
        DownloadRuntimeCodec.encodePreparedBatch(batch),
      );
      final decodedResult = DownloadRuntimeCodec.decodeEnqueuedResult(
        DownloadRuntimeCodec.encodeEnqueuedResult(
          const EnqueuedDownloadsResult(
            queuedCount: 2,
            notices: [notice],
            batchId: 'batch-2',
          ),
        ),
      );

      expect(decodedBatch.unavailableEpisodeNumbers, [4, 7]);
      expect(decodedBatch.notices.single.level, DownloadNoticeLevel.warning);
      expect(decodedBatch.requiresUserInteraction, isTrue);
      expect(decodedResult.queuedCount, 2);
      expect(decodedResult.batchId, 'batch-2');
    });

    test('normalizes invalid torrent settings received across isolates', () {
      final settings = DownloadRuntimeCodec.decodeTorrentSettings({
        'maxActiveDownloads': -2,
        'maxActiveSeeds': -1,
        'maxConnections': 0,
        'seedRatioLimit': -1,
        'seedTimeLimitMinutes': -1,
        'torrentPort': 70000,
        'proxyPort': -1,
        'seedingMode': 'futureMode',
        'anonymousMode': 'yes',
      });

      expect(settings.maxActiveDownloads, 1);
      expect(settings.maxActiveSeeds, -1);
      expect(settings.maxConnections, 200);
      expect(settings.seedRatioLimit, 200);
      expect(settings.seedTimeLimitMinutes, 24 * 60);
      expect(settings.torrentPort, 6881);
      expect(settings.proxyPort, 0);
      expect(settings.seedingMode, TorrentSeedingMode.untilTarget);
      expect(settings.anonymousMode, isFalse);
    });

    test('round trips every torrent preference field', () {
      const settings = TorrentPreferences(
        maxDownloadBytesPerSecond: 1,
        maxUploadBytesPerSecond: 2,
        maxActiveDownloads: 3,
        maxActiveSeeds: 4,
        maxConnections: 5,
        seedRatioLimit: 6,
        seedTimeLimitMinutes: 7,
        seedingMode: TorrentSeedingMode.indefinitely,
        torrentPort: 49152,
        encryptionMode: TorrentEncryptionMode.forced,
        anonymousMode: true,
        enableIncomingTcp: false,
        enableIncomingUtp: false,
        enableOutgoingTcp: false,
        enableOutgoingUtp: false,
        enableDht: false,
        enableLsd: false,
        enableUpnp: false,
        enableNatPmp: false,
        proxyMode: TorrentProxyMode.socks5Password,
        proxyHost: 'proxy.example',
        proxyPort: 1080,
        proxyUsername: 'user',
        proxyPassword: 'secret',
      );

      final decoded = DownloadRuntimeCodec.decodeTorrentSettings(
        DownloadRuntimeCodec.encodeTorrentSettings(settings),
      );

      expect(decoded.maxActiveDownloads, 3);
      expect(decoded.seedingMode, TorrentSeedingMode.indefinitely);
      expect(decoded.encryptionMode, TorrentEncryptionMode.forced);
      expect(decoded.proxyMode, TorrentProxyMode.socks5Password);
      expect(decoded.proxyPassword, 'secret');
      expect(decoded.enableDht, isFalse);
    });
  });
}
