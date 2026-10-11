part of 'in_process_runtime.dart';

extension _RuntimeHttp on InProcessDownloadRuntime {
  Future<String> _enqueueHttp(
    PreparedHttpDownloadJob job, {
    required String batchId,
  }) async {
    final id = _nextId();
    _jobs[id] = job;
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
    _pendingStarters[id] = () => unawaited(_startHttp(id));
    return id;
  }

  Future<void> _startHttp(String id) async {
    final generation = _generations[id] ?? 0;
    if (!_currentAttempt(id, generation)) return;
    var job = _jobs[id] as PreparedHttpDownloadJob;
    var prepared = false;
    _updateItem(
      id,
      (i) =>
          i.copyWith(status: DownloadQueueStatus.recovering, bytesPerSecond: 0),
    );
    _ActiveHttpDownload? active;
    try {
      if (_refreshRequired.remove(id)) {
        _updateItem(
          id,
          (i) => i.copyWith(
            status: DownloadQueueStatus.recovering,
            bytesPerSecond: 0,
          ),
        );
        final refresh = refreshHttp;
        if (refresh == null) {
          throw StateError(
            'Source recovery is unavailable. Reopen the app and retry.',
          );
        }
        job = await refresh(job).timeout(const Duration(minutes: 2));
        if (!_currentAttempt(id, generation)) return;
        DownloadRepository.validateJob(job);
        _jobs[id] = job;
        _updateItem(
          id,
          (i) => i.copyWith(
            totalBytes: job.totalBytes,
            downloadedBytes: i.downloadedBytes.clamp(0, job.totalBytes),
          ),
        );
        await _saveQueue();
      }
      if (!_currentAttempt(id, generation)) return;
      if (state.activeBatchId != _findItem(id)?.batchId) {
        _updateItem(
          id,
          (i) =>
              i.copyWith(status: DownloadQueueStatus.queued, bytesPerSecond: 0),
        );
        _pendingStarters[id] = () => unawaited(_startHttp(id));
        return;
      }
      final download = Download(
        params: DownloadParams(
          url: job.resolvedUrl,
          targetFile: File(job.targetFilePath),
          sizeBytes: job.totalBytes,
          numberOfParts:
              _httpConnectionsPerDownload ==
                  DownloadPreferences.automaticConnectionsPerDownload
              ? InProcessDownloadRuntime._recommendedPartCount(job.totalBytes)
              : _httpConnectionsPerDownload,
          headers: job.headers,
        ),
        dio: _downloadDio,
        checkpointFile: _httpCheckpointFile(id),
        onRestored: (bytes, reason) {
          if (_closing ||
              (_generations[id] ?? 0) != generation ||
              _findItem(id) == null ||
              _findItem(id)!.status.isTerminal) {
            return;
          }
          prepared = true;
          _updateItem(
            id,
            (i) => i.copyWith(
              downloadedBytes: bytes,
              status: _userPaused.contains(id)
                  ? DownloadQueueStatus.paused
                  : active?.pausedForQueueSlot == true
                  ? DownloadQueueStatus.queued
                  : DownloadQueueStatus.downloading,
              errorTitle: reason == null ? null : 'Download restarted',
              errorDescription: reason,
              clearError: reason == null,
            ),
          );
        },
      );
      bool owns() =>
          !_closing &&
          identical(_httpDownloads[id], active) &&
          (_generations[id] ?? 0) == generation;
      final progress = download.state.progressStream.listen((event) {
        if (!owns()) return;
        _httpProgressRate.record(units: event.bytesDownloaded);
        _updateItem(
          id,
          (i) => i.copyWith(
            status: _userPaused.contains(id)
                ? DownloadQueueStatus.paused
                : active!.pausedForQueueSlot
                ? DownloadQueueStatus.queued
                : DownloadQueueStatus.downloading,
            downloadedBytes: (i.downloadedBytes + event.bytesDownloaded).clamp(
              0,
              i.totalBytes,
            ),
            bytesPerSecond: download.state.rateTracker.bytesPerSecond,
          ),
          publishImmediately: false,
        );
      });
      final rate = download.state.rateTracker.updateStream.listen((bps) {
        if (!owns()) return;
        _updateItem(
          id,
          (i) => i.copyWith(
            bytesPerSecond: i.status == DownloadQueueStatus.downloading
                ? bps
                : 0,
          ),
          publishImmediately: false,
        );
      });
      final status = download.state.statusStream.listen((s) {
        if (!owns() || s.isTerminal || !prepared) return;
        _updateItem(
          id,
          (i) => i.copyWith(
            status: _userPaused.contains(id)
                ? DownloadQueueStatus.paused
                : active!.pausedForQueueSlot
                ? DownloadQueueStatus.queued
                : DownloadQueueStatus.downloading,
            bytesPerSecond: s == DownloadStatus.paused ? 0 : i.bytesPerSecond,
          ),
        );
      });
      active = _ActiveHttpDownload(
        download: download,
        progressSub: progress,
        rateSub: rate,
        statusSub: status,
      );
      _httpDownloads[id] = active;
      await download.startAndWait();
      if (!owns()) return;
      if (download.state.isComplete) {
        _retryCounts.remove(id);
        _updateItem(
          id,
          (i) => i.copyWith(
            status: DownloadQueueStatus.completed,
            downloadedBytes: i.totalBytes,
            bytesPerSecond: 0,
            clearError: true,
          ),
        );
        await _saveQueue();
      } else if (!download.state.isCancelled) {
        throw download.error ??
            StateError('The download stopped before completion.');
      }
    } on Object catch (error, stack) {
      if (_currentAttempt(id, generation)) _handleHttpFailure(id, error, stack);
    } finally {
      if (active != null) {
        if (identical(_httpDownloads[id], active)) _httpDownloads.remove(id);
        await active.dispose();
      }
      if (!_closing) _maybePromote();
    }
  }

  void _handleHttpFailure(String id, Object error, StackTrace stack) {
    final job = _jobs[id] as PreparedHttpDownloadJob;
    final status = error is DioException ? error.response?.statusCode : null;
    final changed = error is DownloadResourceChangedException;
    final expired = [401, 403, 404, 410].contains(status) || changed;
    final transient =
        error is TimeoutException ||
        (error is DioException &&
            (error.type == DioExceptionType.connectionError ||
                error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.receiveTimeout ||
                status == 429 ||
                (status != null && status >= 500)));
    final attempt = (_retryCounts[id] ?? 0) + 1;
    _retryCounts[id] = attempt;
    if ((transient || (expired && job.recovery != null)) && attempt <= 3) {
      if (expired) _refreshRequired.add(id);
      _updateItem(
        id,
        (i) => i.copyWith(
          status: DownloadQueueStatus.waiting,
          bytesPerSecond: 0,
          errorTitle: 'Waiting to retry',
          errorDescription: expired
              ? 'Refreshing access to the selected source file.'
              : 'The server is temporarily unavailable. Your saved progress is retained.',
        ),
      );
      _retryTimers.remove(id)?.cancel();
      final generation = _generations[id] ?? 0;
      _retryTimers[id] = Timer(Duration(seconds: 2 << attempt), () {
        _retryTimers.remove(id);
        if (!_currentAttempt(id, generation)) return;
        _updateItem(id, (i) => i.copyWith(status: DownloadQueueStatus.queued));
        _pendingStarters[id] = () => unawaited(_startHttp(id));
        _maybePromote();
      });
      return;
    }
    final userError = error is DownloadUserError ? error : null;
    _updateItem(
      id,
      (i) => i.copyWith(
        status: DownloadQueueStatus.needsAction,
        bytesPerSecond: 0,
        errorTitle: userError?.title ?? 'Download needs attention',
        errorDescription:
            userError?.description ??
            'Automatic recovery could not finish. Retry when the source is available, or choose the file again from the anime page. Your partial download is retained.',
        // Avoid exposing signed URLs or authentication headers from Dio errors.
        errorCopyPayload: 'Recovery stopped: ${error.runtimeType}',
      ),
    );
    _persistenceLog.warning(
      'HTTP recovery stopped (${error.runtimeType})',
      null,
      stack,
    );
  }
}
