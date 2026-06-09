import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/shared/net/download/download.dart';
import 'package:senpwai/shared/net/download/download_state.dart';
import 'package:senpwai/shared/net/download/shared.dart';
import 'package:senpwai/ui/components/app.dart';
import 'package:senpwai/ui/components/toast.dart';

class DownloadManagerNotifier extends Notifier<DownloadManagerState> {
  static final provider =
      NotifierProvider<DownloadManagerNotifier, DownloadManagerState>(
        DownloadManagerNotifier.new,
      );

  final Map<String, _ActiveHttpDownload> _httpDownloads = {};
  final Map<String, _ActiveTorrentDownload> _torrentDownloads = {};
  final Map<String, void Function()> _pendingStarters = {};
  int _idCounter = 0;

  @override
  DownloadManagerState build() {
    ref.onDispose(_cleanup);
    return const DownloadManagerState();
  }

  Future<EnqueuedDownloadsResult> enqueueBatch(
    PreparedDownloadBatch batch,
  ) async {
    if (batch.jobs.isEmpty) {
      return EnqueuedDownloadsResult(queuedCount: 0, notices: batch.notices);
    }
    final batchId = _nextBatchId();
    final itemIds = <String>[];
    for (final job in batch.jobs) {
      final String itemId;
      switch (job) {
        case PreparedHttpDownloadJob():
          itemId = await _enqueueHttp(job, batchId: batchId);
        case PreparedTorrentDownloadJob():
          itemId = await _enqueueTorrent(job, batchId: batchId);
      }
      itemIds.add(itemId);
    }
    _appendBatch(
      DownloadBatchQueue(
        id: batchId,
        title: _batchTitle(batch.jobs),
        source: batch.jobs.first.source,
        createdAt: DateTime.now(),
        itemIds: itemIds,
      ),
    );
    _maybePromote();
    return EnqueuedDownloadsResult(
      queuedCount: batch.jobs.length,
      notices: batch.notices,
      batchId: batchId,
    );
  }

  Future<void> pause(String id) async {
    final http = _httpDownloads[id];
    if (http != null) {
      http.download.state.pause();
      _updateItem(
        id,
        (item) => item.copyWith(
          status: DownloadQueueStatus.paused,
          bytesPerSecond: 0,
        ),
      );
      return;
    }

    final torrent = _torrentDownloads[id];
    if (torrent != null) {
      torrent.handle.pause();
      _updateItem(
        id,
        (item) => item.copyWith(
          status: DownloadQueueStatus.paused,
          bytesPerSecond: 0,
        ),
      );
    }
  }

  Future<void> resume(String id) async {
    final http = _httpDownloads[id];
    if (http != null) {
      http.download.state.resume();
      _updateItem(
        id,
        (item) => item.copyWith(
          status: DownloadQueueStatus.downloading,
          clearError: true,
        ),
      );
      return;
    }

    final torrent = _torrentDownloads[id];
    if (torrent != null) {
      torrent.handle.resume();
      _updateItem(
        id,
        (item) => item.copyWith(
          status: DownloadQueueStatus.downloading,
          clearError: true,
        ),
      );
    }
  }

  Future<void> cancel(String id) async {
    _pendingStarters.remove(id);
    final http = _httpDownloads.remove(id);
    if (http != null) {
      await http.download.state.cancel();
      await http.dispose();
      _updateItem(
        id,
        (item) => item.copyWith(
          status: DownloadQueueStatus.cancelled,
          bytesPerSecond: 0,
        ),
      );
      _maybePromote();
      return;
    }

    final torrent = _torrentDownloads.remove(id);
    if (torrent != null) {
      await torrent.subscription.cancel();
      torrent.handle.cancel(deleteFiles: true, deletePartfile: true);
      torrent.session.close();
      _updateItem(
        id,
        (item) => item.copyWith(
          status: DownloadQueueStatus.cancelled,
          bytesPerSecond: 0,
        ),
      );
      _maybePromote();
    }
  }

  Future<void> pauseBatch(String batchId) async {
    final itemIds = _itemIdsFor(batchId);
    for (final id in itemIds) {
      final item = _findItem(id);
      if (item == null) continue;
      if (item.status == DownloadQueueStatus.downloading) {
        await pause(id);
      }
    }
  }

  Future<void> resumeBatch(String batchId) async {
    final itemIds = _itemIdsFor(batchId);
    for (final id in itemIds) {
      final item = _findItem(id);
      if (item == null) continue;
      if (item.status == DownloadQueueStatus.paused) {
        await resume(id);
      }
    }
  }

  List<String> _itemIdsFor(String batchId) {
    for (final batch in state.batches) {
      if (batch.id == batchId) return batch.itemIds;
    }
    return const [];
  }

  Future<void> cancelBatch(String batchId) async {
    final itemIds = state.batches
        .where((batch) => batch.id == batchId)
        .expand((batch) => batch.itemIds)
        .toList();
    for (final id in itemIds) {
      final item = _findItem(id);
      if (item == null || item.status.isTerminal) continue;
      await cancel(id);
    }
    final wasActive = state.activeBatchId == batchId;
    state = state.copyWith(
      batches: state.batches.where((batch) => batch.id != batchId).toList(),
      clearActiveBatchId: wasActive,
    );
    if (wasActive) _maybePromote();
  }

  void _cleanup() {
    for (final runtime in _httpDownloads.values) {
      unawaited(runtime.dispose());
    }
    for (final runtime in _torrentDownloads.values) {
      unawaited(runtime.subscription.cancel());
      runtime.session.close();
    }
    _httpDownloads.clear();
    _torrentDownloads.clear();
  }

  Future<String> _enqueueHttp(
    PreparedHttpDownloadJob job, {
    required String batchId,
  }) async {
    final id = _nextId();
    final params = DownloadParams(
      url: job.resolvedUrl,
      targetFile: File(job.targetFilePath),
      sizeBytes: job.totalBytes,
      numberOfParts: _recommendedPartCount(job.totalBytes),
      headers: job.headers,
    );
    final download = Download(params: params);
    final progressSub = download.state.progressStream.listen((progress) {
      _updateItem(
        id,
        (item) => item.copyWith(
          status: download.state.isPaused
              ? DownloadQueueStatus.paused
              : DownloadQueueStatus.downloading,
          downloadedBytes: (item.downloadedBytes + progress.bytesDownloaded)
              .clamp(0, item.totalBytes),
          bytesPerSecond: download.state.rateTracker.bytesPerSecond,
        ),
      );
    });
    final rateSub = download.state.rateTracker.updateStream.listen((bps) {
      _updateItem(id, (item) {
        if (item.status != DownloadQueueStatus.downloading) {
          return item.copyWith(bytesPerSecond: 0);
        }
        return item.copyWith(bytesPerSecond: bps);
      });
    });
    final statusSub = download.state.statusStream.listen((status) async {
      switch (status) {
        case DownloadStatus.downloading:
          _updateItem(
            id,
            (item) => item.copyWith(
              status: DownloadQueueStatus.downloading,
              clearError: true,
            ),
          );
        case DownloadStatus.paused:
          _updateItem(
            id,
            (item) => item.copyWith(
              status: DownloadQueueStatus.paused,
              bytesPerSecond: 0,
            ),
          );
        case DownloadStatus.completed:
          await _disposeHttpRuntime(id);
          _updateItem(
            id,
            (item) => item.copyWith(
              status: DownloadQueueStatus.completed,
              downloadedBytes: item.totalBytes,
              bytesPerSecond: 0,
              filePaths: [job.targetFilePath],
            ),
          );
          _maybePromote();
        case DownloadStatus.cancelled:
          await _disposeHttpRuntime(id);
          _updateItem(
            id,
            (item) => item.copyWith(
              status: DownloadQueueStatus.cancelled,
              bytesPerSecond: 0,
            ),
          );
          _maybePromote();
        case DownloadStatus.failed:
          await _disposeHttpRuntime(id);
          final message = 'Failed to download ${job.displayTitle}.';
          _failItem(
            id,
            title: 'Download failed',
            description: message,
            copyPayload: null,
          );
          _showGlobalError(title: 'Download failed', description: message);
          _maybePromote();
        case DownloadStatus.idle:
          break;
      }
    });

    _httpDownloads[id] = _ActiveHttpDownload(
      download: download,
      progressSub: progressSub,
      rateSub: rateSub,
      statusSub: statusSub,
    );
    _appendItem(
      DownloadQueueItem(
        id: id,
        batchId: batchId,
        source: job.source,
        animeTitle: job.animeTitle,
        displayTitle: job.displayTitle,
        destinationDirectory: job.destinationDirectory,
        status: DownloadQueueStatus.queued,
        totalBytes: job.totalBytes,
        downloadedBytes: 0,
        bytesPerSecond: 0,
        createdAt: DateTime.now(),
        filePaths: [job.targetFilePath],
      ),
    );

    _pendingStarters[id] = () {
      unawaited(
        download.startAndWait().catchError((error, stackTrace) async {
          await _disposeHttpRuntime(id);
          _failItem(
            id,
            title: 'Download failed',
            description: 'Failed to download ${job.displayTitle}.',
            copyPayload: formatErrorForCopy(error, stackTrace),
          );
          _showGlobalError(
            title: 'Download failed',
            description: 'Failed to download ${job.displayTitle}.',
            copyPayload: formatErrorForCopy(error, stackTrace),
          );
          _maybePromote();
        }),
      );
    };
    return id;
  }

  Future<String> _enqueueTorrent(
    PreparedTorrentDownloadJob job, {
    required String batchId,
  }) async {
    final id = _nextId();
    final session = createSession();
    try {
      await Directory(job.destinationDirectory).create(recursive: true);
      for (final filePath in job.selectedFilePaths) {
        await Directory(path.dirname(filePath)).create(recursive: true);
      }
      final handle = session.addTorrentData(
        torrentData: job.torrentData,
        savePath: job.destinationDirectory,
        renamedFiles: job.renamedFilePaths.isEmpty
            ? null
            : job.renamedFilePaths,
      );
      handle.unsetFlags(LibtorrentTorrentFlags.autoManaged);
      final priorities = List<int>.filled(handle.getFiles().length, 0);
      for (final fileIndex in job.selectedFileIndices) {
        priorities[fileIndex] = 7;
      }
      handle.prioritizeFiles(priorities);

      final subscription = handle.listenProgress(
        onData: (status) {
          if (status.error.isNotEmpty) {
            _disposeTorrentRuntime(id);
            _failItem(
              id,
              title: 'Torrent failed',
              description: status.error,
              copyPayload: status.error,
            );
            _showGlobalError(
              title: 'Torrent failed',
              description: status.error,
            );
            _maybePromote();
            return;
          }

          final fileProgress = handle.getFileProgress();
          var downloadedBytes = 0;
          for (final fileIndex in job.selectedFileIndices) {
            if (fileIndex >= 0 && fileIndex < fileProgress.length) {
              downloadedBytes += fileProgress[fileIndex];
            }
          }

          if (downloadedBytes >= job.totalBytes && job.totalBytes > 0) {
            _disposeTorrentRuntime(id);
            _updateItem(
              id,
              (item) => item.copyWith(
                status: DownloadQueueStatus.completed,
                downloadedBytes: job.totalBytes,
                bytesPerSecond: 0,
              ),
            );
            _maybePromote();
            return;
          }

          _updateItem(
            id,
            (item) {
              // Libtorrent emits paused-status events from the moment the
              // torrent is added — before the queue's starter callback ever
              // runs handle.resume(). Don't let those early events flip a
              // never-started item from pending to paused.
              if (item.status == DownloadQueueStatus.queued) {
                return item.copyWith(
                  downloadedBytes: downloadedBytes,
                  clearError: true,
                );
              }
              final paused = status.paused ||
                  item.status == DownloadQueueStatus.paused;
              return item.copyWith(
                status: paused
                    ? DownloadQueueStatus.paused
                    : DownloadQueueStatus.downloading,
                downloadedBytes: downloadedBytes,
                bytesPerSecond: paused ? 0 : status.downloadRate,
                clearError: true,
              );
            },
          );
        },
      );

      _torrentDownloads[id] = _ActiveTorrentDownload(
        session: session,
        handle: handle,
        subscription: subscription,
      );

      _appendItem(
        DownloadQueueItem(
          id: id,
          batchId: batchId,
          source: job.source,
          animeTitle: job.animeTitle,
          displayTitle: job.displayTitle,
          destinationDirectory: job.destinationDirectory,
          status: DownloadQueueStatus.queued,
          totalBytes: job.totalBytes,
          downloadedBytes: 0,
          bytesPerSecond: 0,
          createdAt: DateTime.now(),
          filePaths: job.selectedFilePaths,
        ),
      );

      _pendingStarters[id] = () {
        handle.resume();
        // Flip pending → downloading so subsequent listener events stop
        // treating this item as never-started.
        _updateItem(
          id,
          (item) => item.status == DownloadQueueStatus.queued
              ? item.copyWith(status: DownloadQueueStatus.downloading)
              : item,
        );
      };
    } catch (error, stackTrace) {
      session.close();
      _appendItem(
        DownloadQueueItem(
          id: id,
          batchId: batchId,
          source: job.source,
          animeTitle: job.animeTitle,
          displayTitle: job.displayTitle,
          destinationDirectory: job.destinationDirectory,
          status: DownloadQueueStatus.failed,
          totalBytes: job.totalBytes,
          downloadedBytes: 0,
          bytesPerSecond: 0,
          createdAt: DateTime.now(),
          filePaths: job.selectedFilePaths,
          errorTitle: 'Torrent failed',
          errorDescription: 'Failed to start ${job.displayTitle}.',
          errorCopyPayload: formatErrorForCopy(error, stackTrace),
        ),
      );
      _showGlobalError(
        title: 'Torrent failed',
        description: 'Failed to start ${job.displayTitle}.',
        copyPayload: formatErrorForCopy(error, stackTrace),
      );
    }
    return id;
  }

  String _nextBatchId() {
    _idCounter += 1;
    return 'batch-${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
  }

  String _nextId() {
    _idCounter += 1;
    return 'download-${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
  }

  void _appendItem(DownloadQueueItem item) {
    state = state.copyWith(items: [...state.items, item]);
  }

  void _appendBatch(DownloadBatchQueue batch) {
    state = state.copyWith(batches: [...state.batches, batch]);
  }

  /// If no active batch is running, find the next batch with pending starters
  /// and kick it off. Also clears the active id if its batch is fully terminal.
  void _maybePromote() {
    final activeId = state.activeBatchId;
    if (activeId != null) {
      DownloadBatchQueue? active;
      for (final b in state.batches) {
        if (b.id == activeId) {
          active = b;
          break;
        }
      }
      final allTerminal = active == null ||
          active.itemIds.every((id) {
            final item = _findItem(id);
            return item == null || item.status.isTerminal;
          });
      if (!allTerminal) return;
      state = state.copyWith(clearActiveBatchId: true);
    }
    for (final batch in state.batches) {
      final hasPending =
          batch.itemIds.any((id) => _pendingStarters.containsKey(id));
      if (!hasPending) continue;
      state = state.copyWith(activeBatchId: batch.id);
      for (final id in batch.itemIds) {
        _pendingStarters.remove(id)?.call();
      }
      return;
    }
  }

  void _updateItem(
    String id,
    DownloadQueueItem Function(DownloadQueueItem item) update,
  ) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.id == id) update(item) else item,
      ],
    );
  }

  DownloadQueueItem? _findItem(String id) {
    for (final item in state.items) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _failItem(
    String id, {
    required String title,
    required String description,
    required String? copyPayload,
  }) {
    _updateItem(
      id,
      (item) => item.copyWith(
        status: DownloadQueueStatus.failed,
        bytesPerSecond: 0,
        errorTitle: title,
        errorDescription: description,
        errorCopyPayload: copyPayload,
      ),
    );
  }

  Future<void> _disposeHttpRuntime(String id) async {
    final runtime = _httpDownloads.remove(id);
    if (runtime == null) return;
    await runtime.dispose();
  }

  void _disposeTorrentRuntime(String id) {
    final runtime = _torrentDownloads.remove(id);
    if (runtime == null) return;
    runtime.subscription.cancel();
    runtime.session.close();
  }

  void _showGlobalError({
    required String title,
    required String description,
    String? copyPayload,
  }) {
    final context = App.navigatorKey.currentContext;
    if (context == null) return;
    AppToast.showError(
      context,
      title: title,
      description: description,
      copyPayload: copyPayload,
    );
  }

  void reorder(int oldIndex, int newIndex) {
    final items = [...state.items];
    if (oldIndex < newIndex) newIndex -= 1;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = state.copyWith(items: items);
  }

  void reorderBatch(int oldIndex, int newIndex) {
    final batches = [...state.batches];
    if (oldIndex < 0 || oldIndex >= batches.length) return;
    if (oldIndex < newIndex) newIndex -= 1;
    final clamped = newIndex.clamp(0, batches.length - 1);
    final batch = batches.removeAt(oldIndex);
    batches.insert(clamped, batch);
    state = state.copyWith(batches: batches);
    _reconcileActiveBatch();
  }

  /// Ensures the batch at position 0 is the active one. If a different batch
  /// is currently active, pause its in-flight downloads (runtimes are
  /// retained so we can resume later) and promote the new top batch.
  void _reconcileActiveBatch() {
    if (state.batches.isEmpty) return;
    final top = state.batches.first;
    final activeId = state.activeBatchId;
    if (activeId == top.id) return;

    if (activeId != null) {
      for (final id in _itemIdsFor(activeId)) {
        final item = _findItem(id);
        if (item == null) continue;
        if (item.status == DownloadQueueStatus.downloading) {
          unawaited(pause(id));
        }
      }
      state = state.copyWith(clearActiveBatchId: true);
    }

    final hasPending =
        top.itemIds.any((id) => _pendingStarters.containsKey(id));
    state = state.copyWith(activeBatchId: top.id);
    if (hasPending) {
      for (final id in top.itemIds) {
        _pendingStarters.remove(id)?.call();
      }
    } else {
      for (final id in top.itemIds) {
        final item = _findItem(id);
        if (item == null) continue;
        if (item.status == DownloadQueueStatus.paused) {
          unawaited(resume(id));
        }
      }
    }
  }

  void reorderBatchItem(String batchId, int oldIndex, int newIndex) {
    state = state.copyWith(
      batches: [
        for (final batch in state.batches)
          if (batch.id == batchId)
            batch.copyWith(
              itemIds: _reorderedIds(batch.itemIds, oldIndex, newIndex),
            )
          else
            batch,
      ],
    );
  }

  void clearHistory() {
    final activeIds = state.items
        .where((i) => !i.status.isTerminal)
        .map((item) => item.id)
        .toSet();
    state = state.copyWith(
      items: state.items.where((i) => !i.status.isTerminal).toList(),
      batches: [
        for (final batch in state.batches)
          if (batch.itemIds.any(activeIds.contains))
            batch.copyWith(
              itemIds: batch.itemIds.where(activeIds.contains).toList(),
            ),
      ],
    );
  }

  void dismiss(String id) {
    final item = _findItem(id);
    state = state.copyWith(
      items: state.items.where((i) => i.id != id).toList(),
      batches: [
        for (final batch in state.batches)
          if (item == null || batch.id != item.batchId)
            batch
          else
            batch.copyWith(
              itemIds: batch.itemIds.where((itemId) => itemId != id).toList(),
            ),
      ].where((batch) => batch.itemIds.isNotEmpty).toList(),
    );
  }

  static int _recommendedPartCount(int sizeBytes) {
    if (sizeBytes <= 8 * 1024 * 1024) return 1;
    if (sizeBytes <= 64 * 1024 * 1024) return 2;
    if (sizeBytes <= 256 * 1024 * 1024) return 4;
    return 8;
  }

  static String _batchTitle(List<PreparedDownloadJob> jobs) {
    final first = jobs.first;
    if (jobs.length == 1) return first.displayTitle;
    return '${first.animeTitle} · ${jobs.length} downloads';
  }

  static List<String> _reorderedIds(
    List<String> ids,
    int oldIndex,
    int newIndex,
  ) {
    final reordered = [...ids];
    if (oldIndex < 0 || oldIndex >= reordered.length) return reordered;
    if (oldIndex < newIndex) newIndex -= 1;
    final clamped = newIndex.clamp(0, reordered.length - 1);
    final id = reordered.removeAt(oldIndex);
    reordered.insert(clamped, id);
    return reordered;
  }
}

class _ActiveHttpDownload {
  final Download download;
  final StreamSubscription<DownloadProgress> progressSub;
  final StreamSubscription<double> rateSub;
  final StreamSubscription<DownloadStatus> statusSub;

  const _ActiveHttpDownload({
    required this.download,
    required this.progressSub,
    required this.rateSub,
    required this.statusSub,
  });

  Future<void> dispose() async {
    await progressSub.cancel();
    await rateSub.cancel();
    await statusSub.cancel();
  }
}

class _ActiveTorrentDownload {
  final Session session;
  final TorrentHandle handle;
  final StreamSubscription<TorrentStatus> subscription;

  const _ActiveTorrentDownload({
    required this.session,
    required this.handle,
    required this.subscription,
  });
}
