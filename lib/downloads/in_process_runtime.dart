import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'repository.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/torrent_network_settings.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/error_report.dart';
import 'package:senpwai/shared/net/download/download.dart';
import 'package:senpwai/shared/net/download/download_config.dart';
import 'package:senpwai/shared/net/download/download_dio.dart';
import 'package:senpwai/shared/net/download/download_state.dart';
import 'package:senpwai/shared/net/download/shared.dart';
import 'package:senpwai/shared/performance_trace.dart';
import 'package:senpwai/shared/persistence/app_paths.dart';
import 'package:senpwai/updates/models.dart';
import 'package:senpwai/updates/update_transfer.dart';

part 'runtime_persistence.dart';
part 'runtime_http.dart';

final _persistenceLog = Logger('senpwai.downloads.persistence');

typedef DownloadRuntimeErrorHandler =
    void Function({
      required String title,
      required String description,
      String? copyPayload,
    });

abstract class DownloadRuntime {
  DownloadManagerState get currentState;
  Stream<DownloadManagerState> get stateStream;
  UpdateTransferState get currentUpdateState;
  Stream<UpdateTransferState> get updateStateStream;

  Future<EnqueuedDownloadsResult> enqueueBatch(PreparedDownloadBatch batch);
  Future<void> downloadUpdate(AppRelease release, UpdateArtifact artifact);
  Future<void> cancelUpdateDownload();
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
    required int maxActiveDownloads,
    required int connectionsPerDownload,
    required String userAgent,
  });
  void updateTorrentSettings(TorrentPreferences settings);
  void updateNotificationSettings(NotificationPreferences settings);
  Future<void> checkpoint();
  Future<void> dispose();
}

class InProcessDownloadRuntime implements DownloadRuntime {
  static const _progressPublishInterval = Duration(milliseconds: 100);

  final DownloadRuntimeErrorHandler onError;
  final Dio _downloadDio;
  late final UpdateTransfer _updateTransfer;

  final Map<String, _ActiveHttpDownload> _httpDownloads = {};
  final Map<String, _ActiveTorrentDownload> _torrentDownloads = {};
  final Map<String, _ActiveMockDownload> _mockDownloads = {};
  final Map<String, void Function()> _pendingStarters = {};
  final _scheduledStarts = <String, (int, void Function())>{};
  int _startSequence = 0;
  final _stateController = StreamController<DownloadManagerState>.broadcast();
  Session? _torrentSession;
  late TorrentPreferences _torrentSettings;
  int _maxActiveHttpDownloads;
  int _httpConnectionsPerDownload;
  DownloadManagerState _state = const DownloadManagerState();
  final _httpProgressRate = TimelineRateCounter('downloads.http_progress_rate');
  Timer? _progressPublishTimer;
  bool _progressStateDirty = false;
  int _idCounter = 0;
  late final DownloadRepository _repository;
  late final Directory _recoveryDirectory;
  final Future<PreparedHttpDownloadJob> Function(PreparedHttpDownloadJob)?
  refreshHttp;
  final _jobs = <String, PreparedDownloadJob>{};
  final _userPaused = <String>{};
  final _seedStarted = <String, DateTime>{};
  final _uploaded = <String, int>{};
  final _generations = <String, int>{};
  final _retryTimers = <String, Timer>{};
  final _retryCounts = <String, int>{};
  final _refreshRequired = <String>{};
  final _closingTransfers = <String>{};
  final _torrentSaves = <String, Future<void>>{};
  Timer? _checkpointTimer;
  Future<void>? _initialization;
  Future<void> _enqueueTail = Future.value();
  Future<void>? _checkpointing;
  bool _initialized = false;
  bool _closing = false;
  bool _persistenceErrorShown = false;
  bool _mockMode = false;

  InProcessDownloadRuntime({
    required String downloadUserAgent,
    required int initialMaxDownloadBytesPerSecond,
    required int initialMaxActiveHttpDownloads,
    required int initialHttpConnectionsPerDownload,
    required TorrentPreferences initialTorrentSettings,
    required AppPaths paths,
    required this.onError,
    this.refreshHttp,
  }) : _downloadDio = createDownloadDio(userAgent: downloadUserAgent),
       _maxActiveHttpDownloads = initialMaxActiveHttpDownloads,
       _httpConnectionsPerDownload = initialHttpConnectionsPerDownload,
       _torrentSettings = initialTorrentSettings {
    _repository = DownloadRepository(
      File(path.join(paths.stateDirectory.path, 'downloads.json')),
    );
    _recoveryDirectory = Directory(
      path.join(paths.stateDirectory.path, 'download_recovery'),
    );
    _updateTransfer = UpdateTransfer(paths: paths, dio: _downloadDio);
    DownloadConfig.getInstance().updateMaxBytesPerSecond(
      initialMaxDownloadBytesPerSecond.toDouble(),
    );
  }

  Future<void> initialize() => _initialization ??= _restore();

  @override
  Future<void> checkpoint() => _checkpointAll();

  DownloadManagerState get state => _state;

  set state(DownloadManagerState next) {
    _state = next;
    _scheduleQueueSave();
    _publishStateImmediately();
  }

  void _publishStateImmediately() {
    _progressPublishTimer?.cancel();
    _progressPublishTimer = null;
    _progressStateDirty = false;
    if (!_stateController.isClosed) _stateController.add(_state);
  }

  void _scheduleProgressStatePublication() {
    _progressStateDirty = true;
    if (_progressPublishTimer != null || _stateController.isClosed) return;
    _progressPublishTimer = Timer(_progressPublishInterval, () {
      _progressPublishTimer = null;
      if (!_progressStateDirty || _stateController.isClosed) return;
      _progressStateDirty = false;
      _stateController.add(_state);
    });
  }

  @override
  DownloadManagerState get currentState => state;

  @override
  Stream<DownloadManagerState> get stateStream => _stateController.stream;

  @override
  UpdateTransferState get currentUpdateState => _updateTransfer.currentState;

  @override
  Stream<UpdateTransferState> get updateStateStream =>
      _updateTransfer.stateStream;

  @override
  Future<void> downloadUpdate(AppRelease release, UpdateArtifact artifact) =>
      _updateTransfer.download(release, artifact);

  @override
  Future<void> cancelUpdateDownload() => _updateTransfer.cancel();

  @override
  Future<EnqueuedDownloadsResult> enqueueBatch(PreparedDownloadBatch batch) {
    final operation = _enqueueTail.then((_) => _enqueueBatch(batch));
    _enqueueTail = operation.then<void>((_) {}).catchError((Object _) {});
    return operation;
  }

  Future<EnqueuedDownloadsResult> _enqueueBatch(
    PreparedDownloadBatch batch,
  ) async {
    await initialize();
    if (_closing) throw StateError('Download runtime is shutting down.');
    if (_mockMode) {
      throw StateError(
        'Restart the app before creating real downloads after a mock preview.',
      );
    }
    for (final job in batch.jobs) {
      DownloadRepository.validateJob(job);
    }
    // A payload must have one writer. Reject overlapping output paths before
    // creating any runtimes, including two selections within the same batch.
    final targets = <String>{
      for (final item in state.items.where(
        (i) => !i.status.isTerminal || _closingTransfers.contains(i.id),
      ))
        ...item.filePaths.map((p) => path.normalize(path.absolute(p))),
    };
    for (final job in batch.jobs) {
      final paths = switch (job) {
        PreparedHttpDownloadJob() => [job.targetFilePath],
        PreparedTorrentDownloadJob() => job.selectedFilePaths,
      };
      for (final target in paths) {
        if (!targets.add(path.normalize(path.absolute(target)))) {
          throw StateError(
            'A download already owns this destination: ${path.basename(target)}',
          );
        }
      }
    }
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
    await _saveQueue();
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
    _userPaused.add(id);
    _retryTimers.remove(id)?.cancel();
    final http = _httpDownloads[id];
    final torrent = _torrentDownloads[id];
    if (http == null) _invalidateRecovery(id);
    http?.download.state.pause();
    torrent?.handle.pause();
    if (torrent != null) {
      torrent.pausedForSeedSlot = false;
      torrent.pausedForDownloadSlot = false;
    }
    _updateItem(
      id,
      (i) => i.copyWith(status: DownloadQueueStatus.paused, bytesPerSecond: 0),
    );
    try {
      if (http != null) await http.download.checkpoint();
      if (torrent != null) await _saveTorrent(id, torrent);
      await _saveQueue();
    } on Object catch (e, st) {
      _reportPersistenceError(e, st);
    }
    _maybePromote();
  }

  @override
  Future<void> resume(String id) async {
    if (!_canResumeItem(id)) return;
    _userPaused.remove(id);
    _retryCounts.remove(id);
    final item = _findItem(id)!;
    _ensureBatch(item);
    final http = _httpDownloads[id];
    final torrent = _torrentDownloads[id];
    _updateItem(
      id,
      (i) => i.copyWith(status: DownloadQueueStatus.queued, clearError: true),
    );
    if (http != null || torrent != null) {
      _pendingStarters.putIfAbsent(
        id,
        () => () {
          if (http != null) {
            http.pausedForQueueSlot = false;
            http.download.state.resume();
          }
          if (torrent != null) {
            torrent.pausedForDownloadSlot = false;
            torrent.pausedForSeedSlot = false;
            torrent.handle.resume();
            _reconcileSeedSlots();
          }
        },
      );
    } else if (_jobs[id] case final PreparedDownloadJob job) {
      _invalidateRecovery(id);
      switch (job) {
        case PreparedHttpDownloadJob():
          _pendingStarters[id] = () => unawaited(_startHttp(id));
        case PreparedTorrentDownloadJob():
          await _enqueueTorrent(job, batchId: item.batchId, restoredItem: item);
      }
    } else if (_mockDownloads.containsKey(id)) {
      _updateItem(
        id,
        (i) => i.copyWith(status: DownloadQueueStatus.downloading),
      );
    }
    await _saveQueue();
    _maybePromote();
  }

  @override
  Future<void> cancel(String id) async {
    if (!_canCancelItem(id)) return;
    _closingTransfers.add(id);
    try {
      final cancellingItem = _findItem(id)!;
      final keepCompleted = cancellingItem.isSeedingPhase;
      _invalidateRecovery(id);
      _userPaused.remove(id);
      _updateItem(
        id,
        (i) => i.copyWith(
          status: keepCompleted
              ? DownloadQueueStatus.completed
              : DownloadQueueStatus.cancelled,
          bytesPerSecond: 0,
        ),
      );
      _httpDownloads[id]?.download.state.pause();
      _torrentDownloads[id]?.handle.pause();
      await _saveQueue().catchError(_reportPersistenceError);
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
        await http.download.cancel();
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
        return;
      }
      if (_jobs[id] case final PreparedHttpDownloadJob job) {
        final partial = File('${job.targetFilePath}.senpwai-part');
        if (await partial.exists()) await partial.delete();
      }
      for (final file in [
        _resumeFile(id),
        _httpCheckpointFile(id),
        File('${_httpCheckpointFile(id).path}.bak'),
      ]) {
        if (await file.exists()) await file.delete();
      }
      _removeItemFromBatch(id);
      _maybePromote();
    } finally {
      _closingTransfers.remove(id);
    }
  }

  @override
  Future<void> pauseBatch(String batchId) async {
    final itemIds = _itemIdsFor(batchId);
    for (final id in itemIds) {
      final item = _findItem(id);
      if (item == null) continue;
      if (!item.status.isTerminal &&
          item.status != DownloadQueueStatus.paused &&
          item.status != DownloadQueueStatus.needsAction) {
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
      if (item.status == DownloadQueueStatus.paused ||
          item.status == DownloadQueueStatus.needsAction) {
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
    if (_closing) return;
    _closing = true;
    _checkpointTimer?.cancel();
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _progressPublishTimer?.cancel();
    try {
      await _checkpointing;
    } on Object catch (e, st) {
      _reportPersistenceError(e, st);
    }
    try {
      await _checkpointAll();
    } on Object catch (e, st) {
      _reportPersistenceError(e, st);
    }
    for (final runtime in _httpDownloads.values.toList()) {
      try {
        await runtime.download.suspend();
      } on Object catch (e, st) {
        _reportPersistenceError(e, st);
      }
      await runtime.dispose();
    }
    for (final runtime in _torrentDownloads.values.toList()) {
      await runtime.subscription.cancel();
    }
    for (final save in _torrentSaves.values.toList()) {
      try {
        await save;
      } on Object catch (e, st) {
        _reportPersistenceError(e, st);
      }
    }
    for (final runtime in _mockDownloads.values) {
      runtime.timer.cancel();
    }
    _httpDownloads.clear();
    _torrentDownloads.clear();
    _torrentSession?.close();
    _torrentSession = null;
    _mockDownloads.clear();
    try {
      await _saveQueue();
    } on Object catch (e, st) {
      _reportPersistenceError(e, st);
    }
    await _updateTransfer.dispose();
    _downloadDio.close(force: true);
    await _repository.close();
    await _stateController.close();
  }

  @override
  void seedMockDownloads() {
    if (!kDebugMode || state.items.any((i) => !i.status.isTerminal)) return;
    _mockMode = true;
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

  Future<String> _enqueueTorrent(
    PreparedTorrentDownloadJob job, {
    required String batchId,
    DownloadQueueItem? restoredItem,
  }) async {
    final id = restoredItem?.id ?? _nextId();
    _jobs[id] = job;
    final generation = _generations[id] ?? 0;
    try {
      final session = _getTorrentSession();
      await Directory(job.destinationDirectory).create(recursive: true);
      for (final filePath in job.selectedFilePaths) {
        await Directory(path.dirname(filePath)).create(recursive: true);
      }
      Uint8List? resume;
      final resumeFile = _resumeFile(id);
      if (await resumeFile.exists()) resume = await resumeFile.readAsBytes();
      if (restoredItem != null &&
          (!_currentAttempt(id, generation) && !_userPaused.contains(id))) {
        return id;
      }
      TorrentHandle add(Uint8List? data) => session.addTorrentFromTags([
        LibtorrentTagItem.bytesValue(LibtorrentTag.torTorrent, job.torrentData),
        LibtorrentTagItem.intValue(
          LibtorrentTag.torTorrentSize,
          job.torrentData.length,
        ),
        LibtorrentTagItem.stringValue(
          LibtorrentTag.torSavePath,
          job.destinationDirectory,
        ),
        LibtorrentTagItem.intValue(LibtorrentTag.torPaused, 1),
        LibtorrentTagItem.intValue(LibtorrentTag.torDuplicateIsError, 1),
        LibtorrentTagItem.intValue(LibtorrentTag.torAutoManaged, 0),
        LibtorrentTagItem.renamedFilesValue(
          LibtorrentTag.torRenamedFiles,
          _validatedTorrentRenamePaths(
                job.renamedFilePaths,
                savePath: job.destinationDirectory,
              ) ??
              const {},
        ),
        if (data != null) ...[
          LibtorrentTagItem.bytesValue(LibtorrentTag.torResumeData, data),
          LibtorrentTagItem.intValue(
            LibtorrentTag.torResumeDataSize,
            data.length,
          ),
        ],
      ]);
      late TorrentHandle handle;
      try {
        handle = add(resume);
      } on Object catch (e, st) {
        if (resume == null) rethrow;
        _persistenceLog.warning(
          'Native resume rejected; checking retained files',
          e,
          st,
        );
        handle = add(null);
      }
      handle.unsetFlags(LibtorrentTorrentFlags.autoManaged);
      final torrentFiles = handle.getFiles();
      if (job.selectedFileIndices.any((i) => i >= torrentFiles.length) ||
          job.selectedFileIndices.fold<int>(
                0,
                (sum, i) => sum + torrentFiles[i].size,
              ) !=
              job.totalBytes) {
        session.removeTorrent(handle, deleteFiles: false);
        throw StateError(
          'Saved torrent selection does not match its metadata.',
        );
      }
      final selectedFileSizes = <int, int>{
        for (final file in torrentFiles) file.index: file.size,
      };
      final selectedFilePaths = <int, String>{
        for (var i = 0; i < job.selectedFileIndices.length; i++)
          if (i < job.selectedFilePaths.length)
            job.selectedFileIndices[i]: job.selectedFilePaths[i],
      };

      late final _ActiveTorrentDownload activeDownload;
      final subscription = handle.listenProgress(
        onData: (status) {
          if (_closing || !identical(_torrentDownloads[id], activeDownload)) {
            return;
          }
          if (status.error.isNotEmpty) {
            _disposeTorrentRuntime(id, deleteFiles: false);
            _failItem(
              id,
              title: 'Torrent failed',
              description: status.error,
              copyPayload: formatDiagnosticError(status.error),
            );
            _showGlobalError(
              title: 'Torrent failed',
              description: status.error,
            );
            _maybePromote();
            return;
          }

          final fileProgress = handle.getFileProgress();
          _prioritizeTorrentEpisodes(activeDownload, fileProgress);
          final torrentFileProgress = _torrentFileProgress(
            activeDownload,
            fileProgress,
          );
          var downloadedBytes = 0;
          for (final fileIndex in job.selectedFileIndices) {
            if (fileIndex >= 0 && fileIndex < fileProgress.length) {
              downloadedBytes += fileProgress[fileIndex];
            }
          }

          final selectedFilesDownloaded =
              downloadedBytes >= job.totalBytes && job.totalBytes > 0;
          final seedingEnabled =
              _torrentSettings.seedingMode != TorrentSeedingMode.disabled;
          final beganSeeding =
              selectedFilesDownloaded &&
              seedingEnabled &&
              activeDownload.seedingStartedAt == null;
          if (beganSeeding) {
            activeDownload.seedingStartedAt = DateTime.now();
            _seedStarted[id] = activeDownload.seedingStartedAt!;
            _reconcileSeedSlots();
          }

          _uploaded[id] = activeDownload.uploadedBefore + status.totalUpload;
          final liveStats = TorrentLiveStats(
            uploadBytesPerSecond: status.uploadRate,
            numSeeds: status.numSeeds,
            numPeers: status.numPeers,
            listSeeds: status.listSeeds,
            listPeers: status.listPeers,
            totalUploaded: activeDownload.uploadedBefore + status.totalUpload,
          );

          if (selectedFilesDownloaded &&
              _torrentSeedingTargetMet(
                activeDownload,
                job.totalBytes,
                activeDownload.uploadedBefore + status.totalUpload,
              )) {
            _disposeTorrentRuntime(id, deleteFiles: false);
            _updateItem(
              id,
              (item) => item.copyWith(
                status: DownloadQueueStatus.completed,
                downloadedBytes: job.totalBytes,
                bytesPerSecond: 0,
                torrentStats: liveStats,
                torrentFiles: torrentFileProgress,
                seedingTargetReached:
                    seedingEnabled && activeDownload.seedingStartedAt != null,
              ),
            );
            _maybePromote();
            return;
          }

          _updateItem(id, (item) {
            if (activeDownload.pausedForDownloadSlot) {
              return item.copyWith(
                status: DownloadQueueStatus.queued,
                bytesPerSecond: 0,
                downloadedBytes: downloadedBytes,
                torrentStats: liveStats,
                torrentFiles: torrentFileProgress,
                clearError: true,
              );
            }
            // Libtorrent emits paused-status events from the moment the
            // torrent is added — before the queue's starter callback ever
            // runs handle.resume(). Don't let those early events flip a
            // never-started item from pending to paused.
            if (item.status == DownloadQueueStatus.queued) {
              return item.copyWith(
                downloadedBytes: downloadedBytes,
                torrentStats: liveStats,
                torrentFiles: torrentFileProgress,
                clearError: true,
              );
            }
            final userPaused = _userPaused.contains(id);
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
              torrentFiles: torrentFileProgress,
              clearError: true,
            );
          });
          if (beganSeeding) _maybePromote();
        },
      );

      activeDownload = _ActiveTorrentDownload(
        handle: handle,
        subscription: subscription,
        selectedFileIndices: job.selectedFileIndices,
        selectedFileSizes: selectedFileSizes,
        selectedFilePaths: selectedFilePaths,
        uploadedBefore: _uploaded[id] ?? 0,
      );
      activeDownload.seedingStartedAt = _seedStarted[id];
      _prioritizeTorrentEpisodes(
        activeDownload,
        List<int>.filled(torrentFiles.length, 0),
      );
      _torrentDownloads[id] = activeDownload;

      if (restoredItem == null) {
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
            torrentFiles: _torrentFileProgress(
              activeDownload,
              List<int>.filled(torrentFiles.length, 0),
            ),
          ),
        );
      }

      _pendingStarters[id] = () {
        activeDownload.pausedForDownloadSlot = false;
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
      if (restoredItem == null) {
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
      }
      if (restoredItem != null) {
        _failItem(
          id,
          title: 'Torrent recovery failed',
          description:
              'Could not restore ${job.displayTitle}. Retry to check retained files.',
          copyPayload: _formatErrorForCopy(error, stackTrace),
        );
      }
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
    required int maxActiveDownloads,
    required int connectionsPerDownload,
    required String userAgent,
  }) {
    DownloadConfig.getInstance().updateMaxBytesPerSecond(
      maxBytesPerSecond.toDouble(),
    );
    _maxActiveHttpDownloads = maxActiveDownloads;
    _httpConnectionsPerDownload = connectionsPerDownload;
    _downloadDio.options.headers['User-Agent'] = userAgent;
    _reconcileActiveDownloadLimits();
    _maybePromote();
  }

  @override
  void updateTorrentSettings(TorrentPreferences settings) {
    final previous = _torrentSettings;
    _torrentSettings = settings;
    final session = _torrentSession;
    if (session != null) {
      final networkChanged =
          previous.vpnBindingEnabled != settings.vpnBindingEnabled ||
          previous.vpnInterface != settings.vpnInterface ||
          previous.proxyMode != settings.proxyMode ||
          previous.proxyHost != settings.proxyHost ||
          previous.proxyPort != settings.proxyPort ||
          previous.proxyUsername != settings.proxyUsername ||
          previous.proxyPassword != settings.proxyPassword;
      if (networkChanged || torrentNetworkBlocked(settings)) session.pause();
      _applyTorrentSettings(session, settings);
      if (networkChanged && !torrentNetworkBlocked(settings)) session.resume();
    }
    for (final runtime in _torrentDownloads.values) {
      _prioritizeTorrentEpisodes(runtime, runtime.handle.getFileProgress());
    }
    _reconcileActiveDownloadLimits();
    _reconcileSeedSlots();
    _maybePromote();
  }

  @override
  void updateNotificationSettings(NotificationPreferences settings) {}

  void _applyTorrentSettings(Session session, TorrentPreferences settings) {
    session.applySettingsFromTags(torrentSessionSettings(settings));
  }

  Session _getTorrentSession() {
    final existing = _torrentSession;
    if (existing != null) return existing;
    final session = createSessionFromTags(
      torrentSessionSettings(_torrentSettings),
    );
    if (torrentNetworkBlocked(_torrentSettings)) session.pause();
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

  void _reconcileActiveDownloadLimits() {
    _requeueExcessHttpDownloads();
    _requeueExcessTorrentDownloads();
  }

  void _requeueExcessHttpDownloads() {
    if (_maxActiveHttpDownloads == -1) return;
    final runningIds = state.items
        .where(
          (item) =>
              !item.isTorrent && item.status == DownloadQueueStatus.downloading,
        )
        .map((item) => item.id)
        .toList();
    for (final id in runningIds.skip(_maxActiveHttpDownloads)) {
      final runtime = _httpDownloads[id];
      if (runtime == null) continue;
      runtime.pausedForQueueSlot = true;
      _updateItem(
        id,
        (item) => item.copyWith(
          status: DownloadQueueStatus.queued,
          bytesPerSecond: 0,
        ),
      );
      runtime.download.state.pause();
      _pendingStarters[id] = () {
        runtime.pausedForQueueSlot = false;
        runtime.download.state.resume();
      };
    }
  }

  void _requeueExcessTorrentDownloads() {
    if (_torrentSettings.maxActiveDownloads == -1) return;
    final runningIds = state.items
        .where(
          (item) =>
              item.isTorrent && item.status == DownloadQueueStatus.downloading,
        )
        .map((item) => item.id)
        .toList();
    for (final id in runningIds.skip(_torrentSettings.maxActiveDownloads)) {
      final runtime = _torrentDownloads[id];
      if (runtime == null || runtime.seedingStartedAt != null) continue;
      runtime.pausedForDownloadSlot = true;
      _updateItem(
        id,
        (item) => item.copyWith(
          status: DownloadQueueStatus.queued,
          bytesPerSecond: 0,
        ),
      );
      runtime.handle.pause();
      _pendingStarters[id] = () {
        runtime.pausedForDownloadSlot = false;
        runtime.handle.resume();
        _nudgeTorrentDiscovery(runtime.handle);
      };
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
    if (!_initialized || _closing) return;
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
      _startPendingItems(batch);
      return;
    }
    if (state.activeBatchId != null) {
      state = state.copyWith(clearActiveBatchId: true);
    }
  }

  bool _startPendingItems(DownloadBatchQueue batch) {
    var startedPending = false;
    var httpSlots = _httpSlotsAvailable();
    var torrentSlots = _torrentSlotsAvailable();
    for (final id in batch.itemIds) {
      final pendingItem = _findItem(id);
      if (pendingItem == null ||
          _userPaused.contains(id) ||
          pendingItem.status != DownloadQueueStatus.queued) {
        continue;
      }
      final starter = _pendingStarters.remove(id);
      if (starter == null) continue;
      final item = _findItem(id);
      if (item == null) continue;
      if (item.isTorrent) {
        if (torrentSlots <= 0) {
          _pendingStarters[id] = starter;
          continue;
        }
        torrentSlots -= 1;
      } else {
        if (httpSlots <= 0) {
          _pendingStarters[id] = starter;
          continue;
        }
        httpSlots -= 1;
      }
      startedPending = true;
      _startPendingDownload(id, starter);
    }
    return startedPending;
  }

  void _updateItem(
    String id,
    DownloadQueueItem Function(DownloadQueueItem item) update, {
    bool publishImmediately = true,
  }) {
    final previous = _findItem(id);
    _state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.id == id) update(item) else item,
      ],
    );
    final next = _findItem(id);
    if (previous != null &&
        next != null &&
        (previous.status != next.status ||
            previous.totalBytes != next.totalBytes ||
            previous.errorTitle != next.errorTitle ||
            previous.errorDescription != next.errorDescription ||
            previous.seedingTargetReached != next.seedingTargetReached)) {
      _scheduleQueueSave();
    }
    if (publishImmediately) {
      _publishStateImmediately();
    } else {
      _scheduleProgressStatePublication();
    }
  }

  void _startPendingDownload(String id, void Function() starter) {
    final sequence = ++_startSequence;
    _scheduledStarts[id] = (sequence, starter);
    _updateItem(
      id,
      (item) => item.status == DownloadQueueStatus.queued
          ? item.copyWith(status: DownloadQueueStatus.downloading)
          : item,
    );
    Timer.run(() async {
      try {
        await _saveQueue();
      } on Object catch (e, st) {
        _reportPersistenceError(e, st);
        if (_scheduledStarts[id]?.$1 != sequence ||
            _findItem(id)?.status.isTerminal == true ||
            _userPaused.contains(id)) {
          return;
        }
        _scheduledStarts.remove(id);
        _updateItem(
          id,
          (i) => i.copyWith(
            status: DownloadQueueStatus.needsAction,
            bytesPerSecond: 0,
            errorTitle: 'Download could not be saved',
            errorDescription: 'Check disk space and retry.',
          ),
        );
        return;
      }
      if (_scheduledStarts[id]?.$1 != sequence) return;
      _scheduledStarts.remove(id);
      final item = _findItem(id);
      if (_closing || item == null || item.status.isTerminal) return;
      if (_userPaused.contains(id) || state.activeBatchId != item.batchId) {
        _pendingStarters[id] = starter;
        return;
      }
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

  void _prioritizeTorrentEpisodes(
    _ActiveTorrentDownload runtime,
    List<int> fileProgress,
  ) {
    final activeLimit = _torrentSettings.maxActiveDownloads;
    var remainingSlots = activeLimit == -1
        ? runtime.selectedFileIndices.length
        : activeLimit;
    final activeIndices = <int>{};
    for (final fileIndex in runtime.selectedFileIndices) {
      final fileSize = runtime.selectedFileSizes[fileIndex] ?? 0;
      final downloaded = fileIndex >= 0 && fileIndex < fileProgress.length
          ? fileProgress[fileIndex]
          : 0;
      if (fileSize > 0 && downloaded >= fileSize) continue;
      if (remainingSlots <= 0) break;
      activeIndices.add(fileIndex);
      remainingSlots--;
    }
    if (runtime.prioritizedFileIndices.length == activeIndices.length &&
        runtime.prioritizedFileIndices.containsAll(activeIndices)) {
      return;
    }
    final priorities = List<int>.filled(fileProgress.length, 0);
    for (final fileIndex in activeIndices) {
      if (fileIndex >= 0 && fileIndex < priorities.length) {
        priorities[fileIndex] = 7;
      }
    }
    runtime.handle.prioritizeFiles(priorities);
    runtime.prioritizedFileIndices = activeIndices;
  }

  List<TorrentFileProgress> _torrentFileProgress(
    _ActiveTorrentDownload runtime,
    List<int> fileProgress,
  ) {
    return [
      for (final fileIndex in runtime.selectedFileIndices)
        TorrentFileProgress(
          path: runtime.selectedFilePaths[fileIndex] ?? '',
          totalBytes: runtime.selectedFileSizes[fileIndex] ?? 0,
          downloadedBytes: fileIndex >= 0 && fileIndex < fileProgress.length
              ? fileProgress[fileIndex]
              : 0,
          isActive: runtime.prioritizedFileIndices.contains(fileIndex),
        ),
    ];
  }

  DownloadQueueItem? _findItem(String id) {
    for (final item in state.items) {
      if (item.id == id) return item;
    }
    return null;
  }

  bool _blocksQueuePromotion(DownloadQueueItem item) =>
      !item.status.isTerminal &&
      item.status != DownloadQueueStatus.seeding &&
      item.status != DownloadQueueStatus.needsAction &&
      !_userPaused.contains(item.id);

  int _torrentSlotsAvailable() {
    if (_torrentSettings.maxActiveDownloads == -1) {
      return 1 << 30;
    }
    final running = state.items.where((item) {
      return item.isTorrent && item.status == DownloadQueueStatus.downloading;
    }).length;
    return _torrentSettings.maxActiveDownloads - running;
  }

  int _httpSlotsAvailable() {
    if (_maxActiveHttpDownloads == -1) return 1 << 30;
    final running = state.items.where((item) {
      return !item.isTorrent &&
          (item.status == DownloadQueueStatus.downloading ||
              item.status == DownloadQueueStatus.recovering);
    }).length;
    return _maxActiveHttpDownloads - running;
  }

  bool _canPauseItem(String id) {
    final item = _findItem(id);
    return item != null &&
        !item.status.isTerminal &&
        item.status != DownloadQueueStatus.paused &&
        item.status != DownloadQueueStatus.needsAction;
  }

  bool _canResumeItem(String id) {
    final item = _findItem(id);
    return !_closing &&
        item != null &&
        [
          DownloadQueueStatus.paused,
          DownloadQueueStatus.failed,
          DownloadQueueStatus.needsAction,
        ].contains(item.status);
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

  void _disposeTorrentRuntime(String id, {required bool deleteFiles}) {
    final runtime = _torrentDownloads.remove(id);
    if (runtime == null) return;
    runtime.subscription.cancel();
    if (!deleteFiles) {
      final data = runtime.handle.getResumeData(flags: 2);
      unawaited(
        _writeTorrentResume(id, data).catchError(_reportPersistenceError),
      );
    }
    _torrentSession?.removeTorrent(runtime.handle, deleteFiles: deleteFiles);
    _reconcileSeedSlots();
  }

  void _showGlobalError({
    required String title,
    required String description,
    String? copyPayload,
  }) {
    onError(
      title: title,
      description: description,
      copyPayload: copyPayload ?? formatDiagnosticError(description),
    );
  }

  @override
  void reorder(int oldIndex, int newIndex) {
    final items = [...state.items];
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = state.copyWith(items: items);
  }

  @override
  void reorderBatch(int oldIndex, int newIndex) {
    final batches = [...state.batches];
    if (oldIndex < 0 || oldIndex >= batches.length) return;
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
        if (item.status == DownloadQueueStatus.downloading ||
            item.status == DownloadQueueStatus.recovering) {
          final http = _httpDownloads[id];
          final torrent = _torrentDownloads[id];
          if (http != null) {
            http.pausedForQueueSlot = true;
            http.download.state.pause();
          }
          if (torrent != null) {
            torrent.pausedForDownloadSlot = true;
            torrent.handle.pause();
          }
          _updateItem(
            id,
            (i) => i.copyWith(
              status: DownloadQueueStatus.queued,
              bytesPerSecond: 0,
            ),
          );
          if (http == null && torrent == null && _scheduledStarts[id] == null) {
            _invalidateRecovery(id);
            _refreshRequired.add(id);
            _pendingStarters[id] = () => unawaited(_startHttp(id));
          } else {
            _pendingStarters[id] =
                _scheduledStarts[id]?.$2 ??
                () {
                  if (http != null) {
                    http.pausedForQueueSlot = false;
                    http.download.state.resume();
                  }
                  if (torrent != null) {
                    torrent.pausedForDownloadSlot = false;
                    torrent.handle.resume();
                  }
                };
          }
        }
      }
      state = state.copyWith(clearActiveBatchId: true);
    }

    state = state.copyWith(activeBatchId: top.id);
    _startPendingItems(top);
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
    if (item == null ||
        (!item.status.isTerminal &&
            item.status != DownloadQueueStatus.needsAction)) {
      return;
    }
    _invalidateRecovery(id);
    state = state.copyWith(
      items: state.items.where((i) => i.id != id).toList(),
      batches: [
        for (final batch in state.batches)
          if (batch.id != item.batchId)
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
  bool pausedForQueueSlot = false;

  _ActiveHttpDownload({
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
  final List<int> selectedFileIndices;
  final Map<int, int> selectedFileSizes;
  final Map<int, String> selectedFilePaths;
  Set<int> prioritizedFileIndices = const {};
  DateTime? seedingStartedAt;
  bool pausedForSeedSlot = false;
  bool pausedForDownloadSlot = false;
  final int uploadedBefore;

  _ActiveTorrentDownload({
    required this.handle,
    required this.subscription,
    required this.selectedFileIndices,
    required this.selectedFileSizes,
    required this.selectedFilePaths,
    this.uploadedBefore = 0,
  });
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

Map<int, String>? _validatedTorrentRenamePaths(
  Map<int, String> renamedFiles, {
  required String savePath,
}) {
  if (renamedFiles.isEmpty) return null;

  final normalizedSavePath = path.normalize(path.absolute(savePath));
  return {
    for (final entry in renamedFiles.entries)
      entry.key: _relativeTorrentRenamePath(
        entry.value,
        savePath: normalizedSavePath,
      ),
  };
}

String _relativeTorrentRenamePath(String filePath, {required String savePath}) {
  final normalizedPath = path.normalize(filePath);
  final relativePath = path.isAbsolute(normalizedPath)
      ? path.relative(normalizedPath, from: savePath)
      : normalizedPath;
  final segments = path.split(relativePath);
  final escapesSaveDirectory = segments.isNotEmpty && segments.first == '..';
  if (relativePath.isEmpty ||
      relativePath == '.' ||
      path.isAbsolute(relativePath) ||
      escapesSaveDirectory) {
    throw ArgumentError.value(
      filePath,
      'renamedFiles',
      'Torrent file names must stay within the save directory.',
    );
  }
  return relativePath;
}

String _formatErrorForCopy(Object error, StackTrace stackTrace) =>
    formatDiagnosticError(error, stackTrace);
