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
  int _idCounter = 0;

  @override
  DownloadManagerState build() {
    ref.onDispose(_cleanup);
    return const DownloadManagerState();
  }

  Future<EnqueuedDownloadsResult> enqueueBatch(
    PreparedDownloadBatch batch,
  ) async {
    for (final job in batch.jobs) {
      switch (job) {
        case PreparedHttpDownloadJob():
          await _enqueueHttp(job);
        case PreparedTorrentDownloadJob():
          await _enqueueTorrent(job);
      }
    }
    return EnqueuedDownloadsResult(
      queuedCount: batch.jobs.length,
      notices: batch.notices,
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
    }
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

  Future<void> _enqueueHttp(PreparedHttpDownloadJob job) async {
    final id = _nextId();
    final sanitizedName = _sanitizeFileName(job.fileName);
    final extension = path.extension(sanitizedName).replaceFirst('.', '');
    final title = path.basenameWithoutExtension(sanitizedName);
    final params = DownloadParams(
      url: job.resolvedUrl,
      title: title,
      fileExtension: extension,
      downloadDirectory: Directory(job.destinationDirectory),
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
      _updateItem(id, (item) => item.copyWith(bytesPerSecond: bps));
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
            ),
          );
        case DownloadStatus.cancelled:
          await _disposeHttpRuntime(id);
          _updateItem(
            id,
            (item) => item.copyWith(
              status: DownloadQueueStatus.cancelled,
              bytesPerSecond: 0,
            ),
          );
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
    _prependItem(
      DownloadQueueItem(
        id: id,
        source: job.source,
        animeTitle: job.animeTitle,
        displayTitle: sanitizedName,
        destinationDirectory: job.destinationDirectory,
        status: DownloadQueueStatus.queued,
        totalBytes: job.totalBytes,
        downloadedBytes: 0,
        bytesPerSecond: 0,
        createdAt: DateTime.now(),
      ),
    );

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
      }),
    );
  }

  Future<void> _enqueueTorrent(PreparedTorrentDownloadJob job) async {
    final id = _nextId();
    final session = createSession();
    try {
      final handle = session.addTorrentData(
        torrentData: job.torrentData,
        savePath: job.destinationDirectory,
      );
      handle.unsetFlags(LibtorrentTorrentFlags.autoManaged);
      final priorities = List<int>.filled(handle.getFiles().length, 0);
      for (final fileIndex in job.selectedFileIndices) {
        priorities[fileIndex] = 7;
      }
      handle.prioritizeFiles(priorities);
      handle.resume();

      final subscription = handle.listenProgress(onData: (status) {
        if (status.error.isNotEmpty) {
          _disposeTorrentRuntime(id);
          _failItem(
            id,
            title: 'Torrent failed',
            description: status.error,
            copyPayload: status.error,
          );
          _showGlobalError(title: 'Torrent failed', description: status.error);
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
          return;
        }

        _updateItem(
          id,
          (item) => item.copyWith(
            status: status.paused
                ? DownloadQueueStatus.paused
                : DownloadQueueStatus.downloading,
            downloadedBytes: downloadedBytes,
            bytesPerSecond: status.downloadRate,
            clearError: true,
          ),
        );
      });

      _torrentDownloads[id] = _ActiveTorrentDownload(
        session: session,
        handle: handle,
        subscription: subscription,
      );

      _prependItem(
        DownloadQueueItem(
          id: id,
          source: job.source,
          animeTitle: job.animeTitle,
          displayTitle: job.displayTitle,
          destinationDirectory: job.destinationDirectory,
          status: DownloadQueueStatus.downloading,
          totalBytes: job.totalBytes,
          downloadedBytes: 0,
          bytesPerSecond: 0,
          createdAt: DateTime.now(),
          filePaths: job.selectedFilePaths,
        ),
      );
    } catch (error, stackTrace) {
      session.close();
      _prependItem(
        DownloadQueueItem(
          id: id,
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
  }

  String _nextId() {
    _idCounter += 1;
    return 'download-${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
  }

  void _prependItem(DownloadQueueItem item) {
    state = state.copyWith(items: [item, ...state.items]);
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

  static int _recommendedPartCount(int sizeBytes) {
    if (sizeBytes <= 8 * 1024 * 1024) return 1;
    if (sizeBytes <= 64 * 1024 * 1024) return 2;
    if (sizeBytes <= 256 * 1024 * 1024) return 4;
    return 8;
  }

  static String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
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
