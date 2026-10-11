import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/repository.dart';
import 'package:senpwai/shared/persistence/json_file_store.dart';

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('download-persistence-');
    file = File('${directory.path}/downloads.json');
  });
  tearDown(() async => directory.delete(recursive: true));

  PreparedHttpDownloadJob job(int n) => PreparedHttpDownloadJob(
    source: AnimeSource.animepahe,
    animeTitle: 'Show',
    displayTitle: 'Episode $n',
    destinationDirectory: directory.path,
    totalBytes: 100,
    resolvedUrl: 'https://example.com/$n',
    fileName: '$n.mp4',
    recovery: HttpRecoveryRecipe(
      animeLocator: 'show',
      episode: n,
      sourceFileName: 'original-$n',
      resolution: '1080p',
      language: 'Japanese',
    ),
  );
  Future<void> saveQueue() async {
    final jobs = {for (var n = 1; n <= 3; n++) '$n': job(n)};
    final items = [
      for (var n = 1; n <= 3; n++)
        DownloadQueueItem(
          id: '$n',
          batchId: n == 3 ? 'later' : 'first',
          source: AnimeSource.animepahe,
          animeTitle: 'Show',
          displayTitle: 'Episode $n',
          destinationDirectory: directory.path,
          totalBytes: 100,
          downloadedBytes: n == 1 ? 40 : 0,
          bytesPerSecond: 12,
          status: n == 1
              ? DownloadQueueStatus.downloading
              : DownloadQueueStatus.queued,
          createdAt: DateTime.utc(2026),
          filePaths: [jobs['$n']!.targetFilePath],
        ),
    ];
    final batches = [
      for (final id in ['first', 'later'])
        DownloadBatchQueue(
          id: id,
          title: 'Show',
          source: AnimeSource.animepahe,
          createdAt: DateTime.utc(2026),
          itemIds: id == 'first' ? ['2', '1'] : ['3'],
        ),
    ];
    await DownloadRepository(file).save(
      DownloadManagerState(items: items, batches: batches),
      jobs,
      {'2'},
      {},
      {'1': 9},
      {'1': 2},
      {'1'},
    );
  }

  test(
    'fresh repository restores the entire queue and exact source selection',
    () async {
      await saveQueue();
      final restored = await DownloadRepository(file).load();
      expect(restored.state.items.map((i) => i.id), ['1', '2', '3']);
      expect(restored.state.batches.map((b) => b.id), ['first', 'later']);
      expect(restored.state.batches.first.itemIds, ['2', '1']);
      expect(restored.userPaused, {'2'});
      expect(restored.retries['1'], 2);
      expect(restored.refreshPending, {'1'});
      expect(restored.uploaded['1'], 9);
      expect(restored.state.items.first.downloadedBytes, 40);
      expect(restored.state.items.first.bytesPerSecond, 0);
      final recovered = restored.jobs['3'] as PreparedHttpDownloadJob;
      expect(recovered.recovery!.episode, 3);
      expect(recovered.recovery!.resolution, '1080p');
      expect(recovered.recovery!.sourceFileName, 'original-3');
    },
  );

  test(
    'one invalid record leaves healthy jobs recoverable and preserves evidence',
    () async {
      await saveQueue();
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      json['records'][0]['item']['downloadedBytes'] = 101;
      await file.writeAsString(jsonEncode(json));
      final repository = DownloadRepository(file);
      final restored = await repository.load();
      expect(repository.rejectedRecords, 1);
      expect(restored.jobs.keys, ['2', '3']);
      expect(
        directory.listSync().any((f) => f.path.endsWith('.damaged')),
        isTrue,
      );
    },
  );

  test(
    'torrent metadata, selection and seeding state survive reopening',
    () async {
      final job = PreparedTorrentDownloadJob(
        source: AnimeSource.nyaa,
        animeTitle: 'Show',
        displayTitle: 'Batch',
        destinationDirectory: directory.path,
        totalBytes: 100,
        torrentData: Uint8List.fromList([0, 1, 127, 255]),
        torrentName: 'show.torrent',
        selectedFileIndices: [1],
        selectedFilePaths: ['${directory.path}/episode.mkv'],
        renamedFilePaths: {1: 'episode.mkv'},
      );
      final started = DateTime.utc(2026, 10, 1);
      final item = DownloadQueueItem(
        id: 'torrent',
        bytesPerSecond: 0,
        batchId: 'batch',
        source: AnimeSource.nyaa,
        animeTitle: 'Show',
        displayTitle: 'Batch',
        destinationDirectory: directory.path,
        totalBytes: 100,
        downloadedBytes: 100,
        status: DownloadQueueStatus.seeding,
        createdAt: started,
        filePaths: job.selectedFilePaths,
      );
      await DownloadRepository(file).save(
        DownloadManagerState(items: [item]),
        {'torrent': job},
        {},
        {'torrent': started},
        {'torrent': 250},
        {},
        {},
      );
      final restored = await DownloadRepository(file).load();
      final recovered = restored.jobs['torrent'] as PreparedTorrentDownloadJob;
      expect(recovered.torrentData, job.torrentData);
      expect(recovered.selectedFileIndices, [1]);
      expect(recovered.renamedFilePaths, {1: 'episode.mkv'});
      expect(restored.seedStarted['torrent'], started);
      expect(restored.uploaded['torrent'], 250);
      expect(restored.state.items.single.status, DownloadQueueStatus.seeding);
      expect(restored.state.batches.single.itemIds, ['torrent']);
    },
  );

  test('corrupt primary recovers backup and quarantines primary', () async {
    final store = JsonFileStore(file);
    await store.write({'revision': 1});
    await store.write({'revision': 2});
    await file.writeAsString('{broken');
    final reopened = JsonFileStore(file);
    expect(await reopened.read(), {'revision': 1});
    expect(reopened.unreadable, isFalse);
    expect(
      directory.listSync().any((f) => f.path.endsWith('.corrupt')),
      isTrue,
    );
  });

  test('missing primary still recovers backup', () async {
    final store = JsonFileStore(file);
    await store.write({'revision': 1});
    await store.write({'revision': 2});
    await file.delete();
    expect(await JsonFileStore(file).read(), {'revision': 1});
  });

  test('concurrent snapshots finish with the newest durable state', () async {
    final store = JsonFileStore(file);
    await Future.wait([
      for (var n = 0; n < 30; n++) store.write({'revision': n}),
    ]);
    expect(await JsonFileStore(file).read(), {'revision': 29});
    expect(directory.listSync().where((f) => f.path.endsWith('.tmp')), isEmpty);
  });
}
