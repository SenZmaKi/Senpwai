import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/net/download/download.dart';
import 'package:senpwai/shared/net/download/download_config.dart';
import 'package:senpwai/shared/net/download/download_dio.dart';
import 'package:senpwai/shared/net/download/download_state.dart';
import 'package:senpwai/shared/net/download/shared.dart';

typedef DownloadRuntimeErrorHandler =
    void Function({
      required String title,
      required String description,
      String? copyPayload,
    });

abstract class DownloadRuntime {
  DownloadManagerState get currentState;
  Stream<DownloadManagerState> get stateStream;

  Future<EnqueuedDownloadsResult> enqueueBatch(PreparedDownloadBatch batch);
  Future<void> pause(String id);
  Future<void> resume(String id);
  Future<void> cancel(String id);
  Future<void> pauseBatch(String batchId);
  Future<void> resumeBatch(String batchId);
  Future<void> cancelBatch(String batchId);
  void reorder(int oldIndex, int newIndex);
  void reorderBatch(int oldIndex, int newIndex);
  void reorderBatchItem(String batchId, int oldIndex, int newIndex);
  void clearHistory();
  void dismiss(String id);
  void seedMockDownloads();
  void updateHttpDownloadSettings({
    required int maxBytesPerSecond,
    required String userAgent,
  });
  void updateTorrentSettings(TorrentPreferences settings);
  void updateNotificationSettings(NotificationPreferences settings);
  Future<void> dispose();
}

class InProcessDownloadRuntime implements DownloadRuntime {
  final DownloadRuntimeErrorHandler onError;
  final Dio _downloadDio;

  final Map<String, _ActiveHttpDownload> _httpDownloads = {};
  final Map<String, _ActiveTorrentDownload> _torrentDownloads = {};
  final Map<String, _ActiveMockDownload> _mockDownloads = {};
  final Map<String, void Function()> _pendingStarters = {};
  final _stateController = StreamController<DownloadManagerState>.broadcast();
  Session? _torrentSession;
  late TorrentPreferences _torrentSettings;
  DownloadManagerState _state = const DownloadManagerState();
  int _idCounter = 0;

  InProcessDownloadRuntime({
    required String downloadUserAgent,
    required int initialMaxDownloadBytesPerSecond,
    required TorrentPreferences initialTorrentSettings,
    required this.onError,
  }) : _downloadDio = createDownloadDio(userAgent: downloadUserAgent),
       _torrentSettings = initialTorrentSettings {
    DownloadConfig.getInstance().updateMaxBytesPerSecond(
      initialMaxDownloadBytesPerSecond.toDouble(),
    );
  }

  DownloadManagerState get state => _state;

  set state(DownloadManagerState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  @override
  DownloadManagerState get currentState => state;

  @override
  Stream<DownloadManagerState> get stateStream => _stateController.stream;

  @override
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

  @override
  Future<void> pause(String id) async {
    if (!_canPauseItem(id)) return;

    final mock = _mockDownloads[id];
    if (mock != null) {
      _updateItem(
        id,
        (item) => item.copyWith(
          status: DownloadQueueStatus.paused,
          bytesPerSecond: 0,
        ),
      );
      return;
    }

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
      torrent.pausedForSeedSlot = false;
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

  @override
  Future<void> resume(String id) async {
    if (!_canResumeItem(id)) return;

    final mock = _mockDownloads[id];
    if (mock != null) {
      _updateItem(
        id,
        (item) => item.copyWith(
          status: DownloadQueueStatus.downloading,
          clearError: true,
        ),
      );
      return;
    }

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
      torrent.pausedForSeedSlot = false;
      torrent.handle.resume();
      _updateItem(
        id,
        (item) => item.copyWith(
          status: torrent.seedingStartedAt != null
              ? DownloadQueueStatus.seeding
              : DownloadQueueStatus.downloading,
          clearError: true,
        ),
      );
    }
  }

  @override
  Future<void> cancel(String id) async {
    if (!_canCancelItem(id)) return;

    _pendingStarters.remove(id);
    final mock = _mockDownloads.remove(id);
    if (mock != null) {
      mock.timer.cancel();
      _updateItem(
        id,
        (item) => item.copyWith(
          status: DownloadQueueStatus.cancelled,
          bytesPerSecond: 0,
        ),
      );
      _removeItemFromBatch(id);
      _maybePromote();
      return;
    }

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
      _removeItemFromBatch(id);
      _maybePromote();
      return;
    }

    final torrent = _torrentDownloads.remove(id);
    if (torrent != null) {
      final item = _findItem(id);
      final wasSeeding =
          torrent.seedingStartedAt != null ||
          item?.status == DownloadQueueStatus.seeding;
      await torrent.subscription.cancel();
      if (wasSeeding) {
        _torrentSession?.removeTorrent(torrent.handle, deleteFiles: false);
      } else {
        torrent.handle.cancel(deleteFiles: true, deletePartfile: true);
      }
      _updateItem(
        id,
        (item) => item.copyWith(
          status: wasSeeding
              ? DownloadQueueStatus.completed
              : DownloadQueueStatus.cancelled,
          bytesPerSecond: 0,
        ),
      );
      _removeItemFromBatch(id);
      _reconcileSeedSlots();
      _maybePromote();
    }
  }

  @override
  Future<void> pauseBatch(String batchId) async {
    final itemIds = _itemIdsFor(batchId);
    for (final id in itemIds) {
      final item = _findItem(id);
      if (item == null) continue;
      if (item.status == DownloadQueueStatus.downloading ||
          item.status == DownloadQueueStatus.seeding) {
        await pause(id);
      }
    }
  }

  @override
  Future<void> resumeBatch(String batchId) async {
    final itemIds = _itemIdsFor(batchId);
    for (final id in itemIds) {
      final item = _findItem(id);
      if (item == null) continue;
      if (item.status == DownloadQueueStatus.paused &&
          (_isActiveBatch(batchId) || item.isSeedingPhase)) {
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

  @override
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

  @override
  Future<void> dispose() async {
    for (final runtime in _httpDownloads.values) {
      unawaited(runtime.dispose());
    }
    for (final runtime in _torrentDownloads.values) {
      unawaited(runtime.subscription.cancel());
    }
    for (final runtime in _mockDownloads.values) {
      runtime.timer.cancel();
    }
    _httpDownloads.clear();
    _torrentDownloads.clear();
    _torrentSession?.close();
    _torrentSession = null;
    _mockDownloads.clear();
    _downloadDio.close(force: true);
    await _stateController.close();
  }

  @override
  void seedMockDownloads() {
    if (!kDebugMode) return;
    for (final runtime in _httpDownloads.values) {
      unawaited(runtime.dispose());
    }
    for (final runtime in _torrentDownloads.values) {
      unawaited(runtime.subscription.cancel());
    }
    for (final runtime in _mockDownloads.values) {
      runtime.timer.cancel();
    }
    _httpDownloads.clear();
    _torrentDownloads.clear();
    _torrentSession?.close();
    _torrentSession = null;
    _mockDownloads.clear();
    _pendingStarters.clear();
    state = const DownloadManagerState();

    final createdAt = DateTime.now();
    final specs = [
      _MockBatchSpec(
        title: 'Mock batch A · failing item',
        source: AnimeSource.animepahe,
        items: [
          _MockItemSpec('A-01 · clean progress', 160 * 1024 * 1024),
          _MockItemSpec(
            'A-02 · fails at 40%',
            180 * 1024 * 1024,
            shouldFail: true,
          ),
          _MockItemSpec('A-03 · completes later', 220 * 1024 * 1024),
          _MockItemSpec('A-04 · short episode', 96 * 1024 * 1024),
          _MockItemSpec('A-05 · final item', 140 * 1024 * 1024),
        ],
      ),
      _MockBatchSpec(
        title: 'Mock batch B · queued behind failure',
        source: AnimeSource.nyaa,
        items: [
          _MockItemSpec('B-01 · torrent sample', 260 * 1024 * 1024),
          _MockItemSpec('B-02 · torrent sample', 210 * 1024 * 1024),
        ],
      ),
      _MockBatchSpec(
        title: 'Mock batch C · final queued batch',
        source: AnimeSource.tokyoinsider,
        items: [
          _MockItemSpec('C-01 · final queue check', 120 * 1024 * 1024),
          _MockItemSpec('C-02 · final queue check', 150 * 1024 * 1024),
          _MockItemSpec('C-03 · final queue check', 190 * 1024 * 1024),
        ],
      ),
    ];

    for (final batchSpec in specs) {
      final batchId = _nextBatchId();
      final itemIds = <String>[];
      for (final itemSpec in batchSpec.items) {
        final id = _nextId();
        itemIds.add(id);
        _appendItem(
          DownloadQueueItem(
            id: id,
            batchId: batchId,
            source: batchSpec.source,
            animeTitle: batchSpec.title,
            displayTitle: itemSpec.title,
            destinationDirectory: '/mock/downloads/${batchSpec.title}',
            status: DownloadQueueStatus.queued,
            totalBytes: itemSpec.totalBytes,
            downloadedBytes: 0,
            bytesPerSecond: 0,
            createdAt: createdAt,
            filePaths: ['/mock/downloads/${itemSpec.title}.mkv'],
          ),
        );
        _pendingStarters[id] = () =>
            _startMockDownload(id, shouldFail: itemSpec.shouldFail);
      }
      _appendBatch(
        DownloadBatchQueue(
          id: batchId,
          title: batchSpec.title,
          source: batchSpec.source,
          createdAt: createdAt,
          itemIds: itemIds,
        ),
      );
    }
    _maybePromote();
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
    final download = Download(params: params, dio: _downloadDio);
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
            copyPayload: _formatErrorForCopy(error, stackTrace),
          );
          _showGlobalError(
            title: 'Download failed',
            description: 'Failed to download ${job.displayTitle}.',
            copyPayload: _formatErrorForCopy(error, stackTrace),
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
    final session = _getTorrentSession();
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

      late final _ActiveTorrentDownload activeDownload;
      final subscription = handle.listenProgress(
        onData: (status) {
          if (status.error.isNotEmpty) {
            _disposeTorrentRuntime(id, deleteFiles: false);
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

          final selectedFilesDownloaded =
              downloadedBytes >= job.totalBytes && job.totalBytes > 0;
          final beganSeeding =
              selectedFilesDownloaded &&
              activeDownload.seedingStartedAt == null;
          if (beganSeeding) {
            activeDownload.seedingStartedAt = DateTime.now();
            _reconcileSeedSlots();
          }

          final liveStats = TorrentLiveStats(
            uploadBytesPerSecond: status.uploadRate,
            numSeeds: status.numSeeds,
            numPeers: status.numPeers,
            listSeeds: status.listSeeds,
            listPeers: status.listPeers,
            totalUploaded: status.totalUpload,
          );

          if (selectedFilesDownloaded &&
              _torrentSeedingTargetMet(
                activeDownload,
                job.totalBytes,
                status.totalUpload,
              )) {
            _disposeTorrentRuntime(id, deleteFiles: false);
            _updateItem(
              id,
              (item) => item.copyWith(
                status: DownloadQueueStatus.completed,
                downloadedBytes: job.totalBytes,
                bytesPerSecond: 0,
                torrentStats: liveStats,
              ),
            );
            _maybePromote();
            return;
          }

          _updateItem(id, (item) {
            // Libtorrent emits paused-status events from the moment the
            // torrent is added — before the queue's starter callback ever
            // runs handle.resume(). Don't let those early events flip a
            // never-started item from pending to paused.
            if (item.status == DownloadQueueStatus.queued) {
              return item.copyWith(
                downloadedBytes: downloadedBytes,
                torrentStats: liveStats,
                clearError: true,
              );
            }
            final userPaused =
                !activeDownload.pausedForSeedSlot &&
                (status.paused || item.status == DownloadQueueStatus.paused);
            final seeding =
                selectedFilesDownloaded &&
                item.status != DownloadQueueStatus.paused;
            return item.copyWith(
              status: userPaused
                  ? DownloadQueueStatus.paused
                  : seeding
                  ? DownloadQueueStatus.seeding
                  : DownloadQueueStatus.downloading,
              downloadedBytes: downloadedBytes,
              bytesPerSecond: userPaused || seeding ? 0 : status.downloadRate,
              torrentStats: status.paused
                  ? TorrentLiveStats(
                      uploadBytesPerSecond: 0,
                      numSeeds: liveStats.numSeeds,
                      numPeers: liveStats.numPeers,
                      listSeeds: liveStats.listSeeds,
                      listPeers: liveStats.listPeers,
                      totalUploaded: liveStats.totalUploaded,
                    )
                  : liveStats,
              clearError: true,
            );
          });
          if (beganSeeding) _maybePromote();
        },
      );

      activeDownload = _ActiveTorrentDownload(
        handle: handle,
        subscription: subscription,
      );
      _torrentDownloads[id] = activeDownload;

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
        // Flip pending → downloading so subsequent listener events stop
        // treating this item as never-started.
        _updateItem(
          id,
          (item) => item.status == DownloadQueueStatus.queued
              ? item.copyWith(status: DownloadQueueStatus.downloading)
              : item,
        );
        handle.resume();
        _nudgeTorrentDiscovery(handle);
      };
    } catch (error, stackTrace) {
      _disposeTorrentRuntime(id, deleteFiles: false);
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
          errorCopyPayload: _formatErrorForCopy(error, stackTrace),
        ),
      );
      _showGlobalError(
        title: 'Torrent failed',
        description: 'Failed to start ${job.displayTitle}.',
        copyPayload: _formatErrorForCopy(error, stackTrace),
      );
    }
    return id;
  }

  void _startMockDownload(String id, {required bool shouldFail}) {
    _updateItem(
      id,
      (item) => item.status == DownloadQueueStatus.queued
          ? item.copyWith(status: DownloadQueueStatus.downloading)
          : item,
    );
    final item = _findItem(id);
    if (item == null) return;
    final stepBytes = (item.totalBytes / 12).ceil();
    final failAtBytes = (item.totalBytes * 0.4).ceil();
    final timer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      final current = _findItem(id);
      if (current == null || current.status.isTerminal) {
        timer.cancel();
        _mockDownloads.remove(id);
        return;
      }
      if (current.status == DownloadQueueStatus.paused) return;

      var nextBytes = current.downloadedBytes + stepBytes;
      if (nextBytes > current.totalBytes) nextBytes = current.totalBytes;

      if (shouldFail && nextBytes >= failAtBytes) {
        timer.cancel();
        _mockDownloads.remove(id);
        _failItem(
          id,
          title: 'Mock download failed',
          description: '${current.displayTitle} failed during simulation.',
          copyPayload:
              'Mock failure for ${current.displayTitle}\n'
              'This is generated by SENPWAI_MOCK_DOWNLOADS.',
        );
        _showGlobalError(
          title: 'Mock download failed',
          description: '${current.displayTitle} failed during simulation.',
        );
        return;
      }

      if (nextBytes >= current.totalBytes) {
        timer.cancel();
        _mockDownloads.remove(id);
        _updateItem(
          id,
          (item) => item.copyWith(
            status: DownloadQueueStatus.completed,
            downloadedBytes: item.totalBytes,
            bytesPerSecond: 0,
          ),
        );
        _maybePromote();
        return;
      }

      _updateItem(
        id,
        (item) => item.copyWith(
          status: DownloadQueueStatus.downloading,
          downloadedBytes: nextBytes,
          bytesPerSecond: stepBytes / 0.7,
          torrentStats: item.isTorrent
              ? TorrentLiveStats(
                  uploadBytesPerSecond: stepBytes / 4.2,
                  numSeeds: 12,
                  numPeers: 4,
                  listSeeds: 42,
                  listPeers: 16,
                  totalUploaded:
                      (item.torrentStats?.totalUploaded ?? 0) +
                      (stepBytes ~/ 6),
                )
              : item.torrentStats,
        ),
      );
    });
    _mockDownloads[id] = _ActiveMockDownload(timer: timer);
  }

  @override
  void updateHttpDownloadSettings({
    required int maxBytesPerSecond,
    required String userAgent,
  }) {
    DownloadConfig.getInstance().updateMaxBytesPerSecond(
      maxBytesPerSecond.toDouble(),
    );
    _downloadDio.options.headers['User-Agent'] = userAgent;
  }

  @override
  void updateTorrentSettings(TorrentPreferences settings) {
    _torrentSettings = settings;
    final session = _torrentSession;
    if (session != null) {
      _applyTorrentSettings(session, settings);
    }
    _reconcileSeedSlots();
    _maybePromote();
  }

  @override
  void updateNotificationSettings(NotificationPreferences settings) {}

  void _applyTorrentSettings(Session session, TorrentPreferences settings) {
    session.applyConfig(
      SessionConfig(
        downloadRateLimit: settings.maxDownloadBytesPerSecond,
        uploadRateLimit: settings.maxUploadBytesPerSecond,
        connectionsLimit: settings.maxConnections,
        activeDownloads: settings.maxActiveDownloads,
        activeSeeds: settings.maxActiveSeeds,
        seedRatioLimit: settings.seedRatioLimit,
        seedTimeLimit: Duration(minutes: settings.seedTimeLimitMinutes),
        torrentPort: settings.torrentPort,
        outgoingEncryptionPolicy: _encryptionPolicyValue(
          settings.encryptionMode,
        ),
        incomingEncryptionPolicy: _encryptionPolicyValue(
          settings.encryptionMode,
        ),
        allowedEncryptionLevel: LibtorrentEncryptionLevel.both,
        anonymousMode: settings.anonymousMode,
        enableIncomingTcp: settings.enableIncomingTcp,
        enableIncomingUtp: settings.enableIncomingUtp,
        enableOutgoingTcp: settings.enableOutgoingTcp,
        enableOutgoingUtp: settings.enableOutgoingUtp,
        proxy: _proxySetting(settings),
      ),
    );
    session.setDhtEnabled(settings.enableDht);
    session.setLsdEnabled(settings.enableLsd);
    session.setUpnpEnabled(settings.enableUpnp);
    session.setNatPmpEnabled(settings.enableNatPmp);
  }

  Session _getTorrentSession() {
    final existing = _torrentSession;
    if (existing != null) return existing;
    final session = createSession();
    _applyTorrentSettings(session, _torrentSettings);
    _torrentSession = session;
    return session;
  }

  bool _torrentSeedingTargetMet(
    _ActiveTorrentDownload torrent,
    int totalBytes,
    int totalUploaded,
  ) {
    if (_torrentSettings.seedingMode == TorrentSeedingMode.disabled) {
      return true;
    }
    if (_torrentSettings.seedingMode == TorrentSeedingMode.indefinitely) {
      return false;
    }
    final ratioMet =
        _torrentSettings.seedRatioLimit <= 0 ||
        totalUploaded * 100 >= totalBytes * _torrentSettings.seedRatioLimit;
    final seedStartedAt = torrent.seedingStartedAt;
    final timeMet =
        _torrentSettings.seedTimeLimitMinutes <= 0 ||
        (seedStartedAt != null &&
            DateTime.now().difference(seedStartedAt) >=
                Duration(minutes: _torrentSettings.seedTimeLimitMinutes));
    return ratioMet && timeMet;
  }

  void _reconcileSeedSlots() {
    final seedIds = _torrentDownloads.entries
        .where((entry) => entry.value.seedingStartedAt != null)
        .map((entry) => entry.key)
        .toList();
    if (_torrentSettings.maxActiveSeeds == -1) {
      for (final id in seedIds) {
        final torrent = _torrentDownloads[id];
        final item = _findItem(id);
        if (torrent == null ||
            !torrent.pausedForSeedSlot ||
            item?.status == DownloadQueueStatus.paused) {
          continue;
        }
        torrent.pausedForSeedSlot = false;
        torrent.handle.resume();
      }
      return;
    }
    var runningSeeds = seedIds.where((id) {
      final torrent = _torrentDownloads[id];
      final item = _findItem(id);
      return torrent != null &&
          !torrent.pausedForSeedSlot &&
          item?.status != DownloadQueueStatus.paused;
    }).length;
    for (final id in seedIds) {
      if (runningSeeds <= _torrentSettings.maxActiveSeeds) break;
      final torrent = _torrentDownloads[id];
      final item = _findItem(id);
      if (torrent == null ||
          torrent.pausedForSeedSlot ||
          item?.status == DownloadQueueStatus.paused) {
        continue;
      }
      torrent.pausedForSeedSlot = true;
      torrent.handle.pause();
      runningSeeds -= 1;
    }
    for (final id in seedIds) {
      if (runningSeeds >= _torrentSettings.maxActiveSeeds) break;
      final torrent = _torrentDownloads[id];
      final item = _findItem(id);
      if (torrent == null ||
          !torrent.pausedForSeedSlot ||
          item?.status == DownloadQueueStatus.paused) {
        continue;
      }
      torrent.pausedForSeedSlot = false;
      torrent.handle.resume();
      runningSeeds += 1;
    }
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
    _dropTerminalBatches();
    final activeId = state.activeBatchId;
    if (activeId != null) {
      DownloadBatchQueue? active;
      for (final b in state.batches) {
        if (b.id == activeId) {
          active = b;
          break;
        }
      }
      final allTerminal =
          active == null ||
          active.itemIds.every((id) {
            final item = _findItem(id);
            return item == null || !_blocksQueuePromotion(item);
          });
      if (!allTerminal) {
        _startPendingItems(active);
        return;
      }
      state = state.copyWith(clearActiveBatchId: true);
      _dropTerminalBatches();
    }
    for (final batch in state.batches) {
      final hasRunnable = batch.itemIds.any((id) {
        final item = _findItem(id);
        return item != null && _blocksQueuePromotion(item);
      });
      if (!hasRunnable) continue;
      state = state.copyWith(activeBatchId: batch.id);
      final startedPending = _startPendingItems(batch);
      if (!startedPending) {
        for (final id in batch.itemIds) {
          final item = _findItem(id);
          if (item == null) continue;
          if (item.status == DownloadQueueStatus.paused) {
            unawaited(resume(id));
          }
        }
      }
      return;
    }
    if (state.activeBatchId != null) {
      state = state.copyWith(clearActiveBatchId: true);
    }
  }

  bool _startPendingItems(DownloadBatchQueue batch) {
    var startedPending = false;
    var torrentSlots = _torrentSlotsAvailable();
    for (final id in batch.itemIds) {
      final starter = _pendingStarters.remove(id);
      if (starter == null) continue;
      final item = _findItem(id);
      if (item?.isTorrent == true) {
        if (torrentSlots <= 0) {
          _pendingStarters[id] = starter;
          continue;
        }
        torrentSlots -= 1;
      }
      startedPending = true;
      _startPendingDownload(id, starter);
    }
    return startedPending;
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

  void _startPendingDownload(String id, void Function() starter) {
    Timer.run(() {
      final item = _findItem(id);
      if (item == null || item.status.isTerminal) return;
      try {
        starter();
      } on Object catch (error, stackTrace) {
        _failItem(
          id,
          title: 'Download failed',
          description: 'Failed to start ${item.displayTitle}.',
          copyPayload: _formatErrorForCopy(error, stackTrace),
        );
        _showGlobalError(
          title: 'Download failed',
          description: 'Failed to start ${item.displayTitle}.',
          copyPayload: _formatErrorForCopy(error, stackTrace),
        );
      }
    });
  }

  void _nudgeTorrentDiscovery(TorrentHandle handle) {
    try {
      handle.forceReannounce();
    } catch (_) {}
    if (!_torrentSettings.enableDht) return;
    try {
      handle.forceDhtAnnounce();
    } catch (_) {}
  }

  DownloadQueueItem? _findItem(String id) {
    for (final item in state.items) {
      if (item.id == id) return item;
    }
    return null;
  }

  bool _isActiveBatch(String batchId) => state.activeBatchId == batchId;

  bool _isItemInActiveBatch(DownloadQueueItem item) =>
      _isActiveBatch(item.batchId);

  bool _blocksQueuePromotion(DownloadQueueItem item) =>
      !item.status.isTerminal && item.status != DownloadQueueStatus.seeding;

  int _torrentSlotsAvailable() {
    if (_torrentSettings.maxActiveDownloads == -1) {
      return 1 << 30;
    }
    final running = state.items.where((item) {
      return item.isTorrent && item.status == DownloadQueueStatus.downloading;
    }).length;
    return _torrentSettings.maxActiveDownloads - running;
  }

  bool _canPauseItem(String id) {
    final item = _findItem(id);
    if (item == null) return false;
    if (item.status == DownloadQueueStatus.seeding) return true;
    return _isItemInActiveBatch(item) &&
        item.status == DownloadQueueStatus.downloading;
  }

  bool _canResumeItem(String id) {
    final item = _findItem(id);
    if (item == null || item.status != DownloadQueueStatus.paused) {
      return false;
    }
    if (_torrentDownloads[id]?.seedingStartedAt != null) return true;
    return _isItemInActiveBatch(item);
  }

  bool _canCancelItem(String id) {
    final item = _findItem(id);
    return item != null && !item.status.isTerminal;
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
    _maybePromote();
  }

  void _dropTerminalBatches() {
    final activeId = state.activeBatchId;
    final retained = <DownloadBatchQueue>[];
    var droppedActive = false;
    for (final batch in state.batches) {
      final hasRunnable = batch.itemIds.any((id) {
        final item = _findItem(id);
        return item != null && !item.status.isTerminal;
      });
      if (hasRunnable) {
        retained.add(batch);
      } else if (batch.id == activeId) {
        droppedActive = true;
      }
    }
    if (retained.length == state.batches.length && !droppedActive) return;
    state = state.copyWith(
      batches: retained,
      clearActiveBatchId: droppedActive,
    );
  }

  void _removeItemFromBatch(String id) {
    var removedActive = false;
    final activeId = state.activeBatchId;
    final batches = <DownloadBatchQueue>[];
    for (final batch in state.batches) {
      if (!batch.itemIds.contains(id)) {
        batches.add(batch);
        continue;
      }
      final itemIds = batch.itemIds.where((itemId) => itemId != id).toList();
      if (itemIds.isEmpty) {
        removedActive = removedActive || batch.id == activeId;
        continue;
      }
      batches.add(batch.copyWith(itemIds: itemIds));
    }
    state = state.copyWith(batches: batches, clearActiveBatchId: removedActive);
  }

  Future<void> _disposeHttpRuntime(String id) async {
    final runtime = _httpDownloads.remove(id);
    if (runtime == null) return;
    await runtime.dispose();
  }

  void _disposeTorrentRuntime(String id, {required bool deleteFiles}) {
    final runtime = _torrentDownloads.remove(id);
    if (runtime == null) return;
    runtime.subscription.cancel();
    _torrentSession?.removeTorrent(runtime.handle, deleteFiles: deleteFiles);
    _reconcileSeedSlots();
  }

  void _showGlobalError({
    required String title,
    required String description,
    String? copyPayload,
  }) {
    onError(title: title, description: description, copyPayload: copyPayload);
  }

  @override
  void reorder(int oldIndex, int newIndex) {
    final items = [...state.items];
    if (oldIndex < newIndex) newIndex -= 1;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = state.copyWith(items: items);
  }

  @override
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
    _dropTerminalBatches();
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

    final hasPending = top.itemIds.any(
      (id) => _pendingStarters.containsKey(id),
    );
    state = state.copyWith(activeBatchId: top.id);
    if (hasPending) {
      for (final id in top.itemIds) {
        final starter = _pendingStarters.remove(id);
        if (starter == null) continue;
        _startPendingDownload(id, starter);
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

  @override
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

  @override
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

  @override
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
  final TorrentHandle handle;
  final StreamSubscription<TorrentStatus> subscription;
  DateTime? seedingStartedAt;
  bool pausedForSeedSlot = false;

  _ActiveTorrentDownload({required this.handle, required this.subscription});
}

class _ActiveMockDownload {
  final Timer timer;

  const _ActiveMockDownload({required this.timer});
}

class _MockBatchSpec {
  final String title;
  final AnimeSource source;
  final List<_MockItemSpec> items;

  const _MockBatchSpec({
    required this.title,
    required this.source,
    required this.items,
  });
}

class _MockItemSpec {
  final String title;
  final int totalBytes;
  final bool shouldFail;

  const _MockItemSpec(this.title, this.totalBytes, {this.shouldFail = false});
}

String _formatErrorForCopy(Object error, StackTrace stackTrace) {
  return 'Error: $error\n'
      'Type: ${error.runtimeType}\n\n'
      'Stack trace:\n'
      '$stackTrace';
}

int _encryptionPolicyValue(TorrentEncryptionMode mode) {
  return switch (mode) {
    TorrentEncryptionMode.forced => LibtorrentEncryptionPolicy.forced,
    TorrentEncryptionMode.enabled => LibtorrentEncryptionPolicy.enabled,
    TorrentEncryptionMode.disabled => LibtorrentEncryptionPolicy.disabled,
  };
}

ProxySetting _proxySetting(TorrentPreferences settings) {
  final proxyEnabled = settings.proxyMode != TorrentProxyMode.none;
  return ProxySetting(
    hostname: proxyEnabled ? settings.proxyHost : '',
    port: proxyEnabled ? settings.proxyPort : 0,
    username: settings.proxyUsername,
    password: settings.proxyPassword,
    type: _proxyTypeValue(settings.proxyMode),
  );
}

int _proxyTypeValue(TorrentProxyMode mode) {
  return switch (mode) {
    TorrentProxyMode.none => LibtorrentProxyType.none,
    TorrentProxyMode.socks4 => LibtorrentProxyType.socks4,
    TorrentProxyMode.socks5 => LibtorrentProxyType.socks5,
    TorrentProxyMode.socks5Password => LibtorrentProxyType.socks5Password,
    TorrentProxyMode.http => LibtorrentProxyType.http,
    TorrentProxyMode.httpPassword => LibtorrentProxyType.httpPassword,
  };
}
