import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/runtime_codec.dart';
import 'package:senpwai/shared/persistence/json_file_store.dart';

final _log = Logger('senpwai.downloads.repository');

class DownloadRestore {
  final DownloadManagerState state;
  final Map<String, PreparedDownloadJob> jobs;
  final Set<String> userPaused;
  final Map<String, DateTime> seedStarted;
  final Map<String, int> uploaded;
  final Map<String, int> retries;
  final Set<String> refreshPending;
  const DownloadRestore(
    this.state,
    this.jobs,
    this.userPaused,
    this.seedStarted,
    this.uploaded,
    this.retries,
    this.refreshPending,
  );
}

class DownloadRepository {
  final JsonFileStore store;
  RandomAccessFile? _lock;
  int rejectedRecords = 0;
  DownloadRepository(File file) : store = JsonFileStore(file);

  Future<void> acquire() async {
    await store.file.parent.create(recursive: true);
    final lock = await File(
      '${store.file.path}.lock',
    ).open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.exclusive);
      _lock = lock;
    } on Object {
      await lock.close();
      rethrow;
    }
  }

  Future<void> close() async {
    await store.flushed;
    await _lock?.unlock();
    await _lock?.close();
    _lock = null;
  }

  Future<DownloadRestore> load() async {
    final json = await store.read();
    if (json == null) {
      return const DownloadRestore(
        DownloadManagerState(),
        {},
        {},
        {},
        {},
        {},
        {},
      );
    }
    if (json['version'] != 1) {
      throw const FormatException('Unsupported saved download queue version.');
    }
    final items = <DownloadQueueItem>[];
    final jobs = <String, PreparedDownloadJob>{};
    final seedStarted = <String, DateTime>{};
    final uploaded = <String, int>{};
    final retries = <String, int>{};
    final refreshPending = <String>{};
    final ids = <String>{};
    for (final raw in json['records'] as List) {
      // One damaged record must not hide all the healthy downloads. Preserve
      // the original JSON on disk; report the rejected record in diagnostics.
      try {
        final record = Map<Object?, Object?>.from(raw as Map);
        final rawItem = Map<Object?, Object?>.from(record['item'] as Map);
        DownloadQueueStatus.values.byName(rawItem['status'] as String);
        AnimeSource.values.byName(rawItem['source'] as String);
        final item = DownloadRuntimeCodec.decodeItem(rawItem);
        if (item.batchId.isEmpty ||
            item.totalBytes <= 0 ||
            item.downloadedBytes < 0 ||
            item.downloadedBytes > item.totalBytes ||
            DateTime.tryParse(rawItem['createdAt'] as String) == null) {
          throw const FormatException('Invalid saved download state.');
        }
        if (item.id.isEmpty || !ids.add(item.id)) {
          throw const FormatException('Duplicate download identity.');
        }
        final jobRaw = record['job'];
        if (jobRaw != null) {
          final rawJob = Map<Object?, Object?>.from(jobRaw as Map);
          if (!['http', 'torrent'].contains(rawJob['type'])) {
            throw const FormatException('Unknown download transport.');
          }
          AnimeSource.values.byName(rawJob['source'] as String);
          final job = DownloadRuntimeCodec.decodePreparedJob(rawJob);
          validateJob(job);
          if (job.source != item.source ||
              job.totalBytes != item.totalBytes ||
              job.destinationDirectory != item.destinationDirectory) {
            throw const FormatException(
              'Download job and queue record disagree.',
            );
          }
          final targets = switch (job) {
            PreparedHttpDownloadJob() => [job.targetFilePath],
            PreparedTorrentDownloadJob() => job.selectedFilePaths,
          };
          if (targets.length != item.filePaths.length ||
              targets.asMap().entries.any(
                (e) =>
                    path.normalize(e.value) !=
                    path.normalize(item.filePaths[e.key]),
              )) {
            throw const FormatException('Saved download paths disagree.');
          }
          jobs[item.id] = job;
        } else if (!item.status.isTerminal) {
          throw const FormatException('Unfinished download has no saved job.');
        }
        final started = DateTime.tryParse(
          record['seedStarted'] as String? ?? '',
        );
        if (started != null) seedStarted[item.id] = started;
        uploaded[item.id] = (record['uploaded'] as int? ?? 0).clamp(0, 1 << 62);
        retries[item.id] = record['retries'] as int? ?? 0;
        if (record['refreshPending'] == true) refreshPending.add(item.id);
        items.add(item.copyWith(bytesPerSecond: 0));
      } on Object catch (error, stack) {
        rejectedRecords++;
        _log.warning('Rejected a damaged download record', error, stack);
      }
    }
    if (rejectedRecords > 0) {
      await store.file.copy(
        '${store.file.path}.${DateTime.now().microsecondsSinceEpoch}.damaged',
      );
    }
    final batches = <DownloadBatchQueue>[];
    final batchIds = <String>{};
    final assigned = <String>{};
    for (final raw in json['batches'] as List) {
      final batch = DownloadRuntimeCodec.decodeBatchQueue(
        Map<Object?, Object?>.from(raw as Map),
      );
      if (!batchIds.add(batch.id)) continue;
      final members = batch.itemIds
          .where(
            (id) =>
                items.any((i) => i.id == id && i.batchId == batch.id) &&
                assigned.add(id),
          )
          .toList();
      if (members.isNotEmpty) batches.add(batch.copyWith(itemIds: members));
    }
    for (final item in items.where(
      (i) => !i.status.isTerminal && !assigned.contains(i.id),
    )) {
      final index = batches.indexWhere((b) => b.id == item.batchId);
      if (index >= 0) {
        batches[index] = batches[index].copyWith(
          itemIds: [...batches[index].itemIds, item.id],
        );
      } else {
        batches.add(
          DownloadBatchQueue(
            id: item.batchId,
            title: item.animeTitle,
            source: item.source,
            createdAt: item.createdAt,
            itemIds: [item.id],
          ),
        );
      }
    }
    return DownloadRestore(
      DownloadManagerState(items: items, batches: batches),
      jobs,
      (json['userPaused'] as List).cast<String>().where(ids.contains).toSet(),
      seedStarted,
      uploaded,
      retries,
      refreshPending,
    );
  }

  Future<void> save(
    DownloadManagerState state,
    Map<String, PreparedDownloadJob> jobs,
    Set<String> userPaused,
    Map<String, DateTime> seedStarted,
    Map<String, int> uploaded,
    Map<String, int> retries,
    Set<String> refreshPending,
  ) => store.write({
    'version': 1,
    'batches': state.batches
        .map(DownloadRuntimeCodec.encodeBatchQueue)
        .toList(),
    'userPaused': userPaused.toList(),
    'records': [
      for (final item in state.items)
        {
          'item': DownloadRuntimeCodec.encodeItem(item),
          'job': jobs[item.id] == null
              ? null
              : DownloadRuntimeCodec.encodePreparedJob(jobs[item.id]!),
          'seedStarted': seedStarted[item.id]?.toIso8601String(),
          'uploaded': uploaded[item.id] ?? 0,
          'retries': retries[item.id] ?? 0,
          'refreshPending': refreshPending.contains(item.id),
        },
    ],
  });

  static void validateJob(PreparedDownloadJob job) {
    if (!path.isAbsolute(job.destinationDirectory) || job.totalBytes <= 0) {
      throw const FormatException(
        'Downloads need an absolute destination and positive file size.',
      );
    }
    switch (job) {
      case PreparedHttpDownloadJob():
        if (job.source == AnimeSource.nyaa) {
          throw const FormatException('Invalid HTTP source.');
        }
        final uri = Uri.tryParse(job.resolvedUrl);
        if (uri == null ||
            !['http', 'https'].contains(uri.scheme) ||
            uri.host.isEmpty ||
            path.isAbsolute(job.fileName) ||
            path.basename(job.fileName) != job.fileName ||
            job.fileName == '.' ||
            job.fileName == '..' ||
            job.fileName.isEmpty) {
          throw const FormatException('Invalid HTTP download target.');
        }
      case PreparedTorrentDownloadJob():
        if (job.source != AnimeSource.nyaa) {
          throw const FormatException('Invalid torrent source.');
        }
        if (job.torrentData.isEmpty ||
            job.selectedFileIndices.isEmpty ||
            job.selectedFileIndices.toSet().length !=
                job.selectedFileIndices.length ||
            job.selectedFileIndices.any((i) => i < 0) ||
            job.selectedFilePaths.length != job.selectedFileIndices.length ||
            job.selectedFilePaths.any(
              (p) => !path.isWithin(job.destinationDirectory, p),
            )) {
          throw const FormatException('Invalid torrent file selection.');
        }
    }
  }
}
