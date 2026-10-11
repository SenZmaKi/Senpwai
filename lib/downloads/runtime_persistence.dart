part of 'in_process_runtime.dart';

extension _RuntimePersistence on InProcessDownloadRuntime {
  Future<void> _restore() async {
    await _repository.acquire();
    final restored = await _repository.load();
    _retryCounts.addAll(restored.retries);
    _refreshRequired.addAll(restored.refreshPending);
    _jobs.addAll(restored.jobs);
    _userPaused.addAll(restored.userPaused);
    _seedStarted.addAll(restored.seedStarted);
    _uploaded.addAll(restored.uploaded);
    _state = restored.state.copyWith(
      items: [
        for (final item in restored.state.items)
          item.status.isTerminal ||
                  item.status == DownloadQueueStatus.needsAction
              ? item
              : item.copyWith(
                  status: _userPaused.contains(item.id)
                      ? DownloadQueueStatus.paused
                      : DownloadQueueStatus.queued,
                  bytesPerSecond: 0,
                  clearError: true,
                ),
      ],
    );
    _publishStateImmediately();
    for (final item in _state.items.toList()) {
      if (item.status.isTerminal ||
          item.status == DownloadQueueStatus.needsAction) {
        continue;
      }
      final job = _jobs[item.id];
      if (job == null) continue;
      switch (job) {
        case PreparedHttpDownloadJob():
          _pendingStarters[item.id] = () => unawaited(_startHttp(item.id));
        case PreparedTorrentDownloadJob():
          await _enqueueTorrent(job, batchId: item.batchId, restoredItem: item);
      }
    }
    _initialized = true;
    _reconcileSeedSlots();
    if (_repository.store.unreadable) {
      _showGlobalError(
        title: 'Saved downloads could not be restored',
        description:
            'The damaged queue files were preserved. Choose those downloads again from their anime pages.',
      );
    }
    if (_repository.rejectedRecords > 0) {
      _showGlobalError(
        title: 'Some saved downloads need attention',
        description:
            '${_repository.rejectedRecords} damaged records could not be restored. Their original queue was preserved for recovery.',
      );
    }
    _checkpointTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_checkpointAll().catchError(_reportPersistenceError));
    });
    await _saveQueue();
    _maybePromote();
  }

  Future<void> _saveQueue() {
    if (!_initialized || _mockMode) return Future.value();
    final ids = state.items.map((i) => i.id).toSet();
    _jobs.removeWhere((id, _) => !ids.contains(id));
    _userPaused.removeWhere((id) => !ids.contains(id));
    return _repository.save(
      state,
      _jobs,
      _userPaused,
      _seedStarted,
      _uploaded,
      _retryCounts,
      _refreshRequired,
    );
  }

  void _scheduleQueueSave() {
    if (!_initialized || _closing) return;
    unawaited(_saveQueue().catchError(_reportPersistenceError));
  }

  void _reportPersistenceError(Object error, StackTrace stack) {
    _persistenceLog.warning(
      'Could not save download recovery state',
      error,
      stack,
    );
    if (_persistenceErrorShown) return;
    _persistenceErrorShown = true;
    _showGlobalError(
      title: 'Download progress could not be saved',
      description:
          'Check available disk space and folder permissions. Progress since the last successful save may need to be downloaded again.',
    );
  }

  File _resumeFile(String id) => File(
    path.join(
      _recoveryDirectory.path,
      '${sha256.convert(utf8.encode(id))}.torrent',
    ),
  );
  File _httpCheckpointFile(String id) => File(
    path.join(
      _recoveryDirectory.path,
      '${sha256.convert(utf8.encode(id))}.http.json',
    ),
  );

  Future<void> _saveTorrent(String id, _ActiveTorrentDownload runtime) async {
    // Native access happens before the first await so removal cannot invalidate
    // the handle while its checkpoint is being collected.
    final data = runtime.handle.getResumeData(flags: 2);
    if (data.isEmpty) {
      throw StateError('Native torrent returned empty resume data.');
    }
    await _writeTorrentResume(id, data);
  }

  Future<void> _writeTorrentResume(String id, Uint8List data) {
    final operation = (_torrentSaves[id] ?? Future.value())
        .catchError((Object _) {})
        .then((_) async {
          final file = _resumeFile(id);
          await file.parent.create(recursive: true);
          final temporary = File('${file.path}.tmp');
          await temporary.writeAsBytes(data, flush: true);
          await temporary.rename(file.path);
        });
    _torrentSaves[id] = operation;
    return operation;
  }

  void _ensureBatch(DownloadQueueItem item) {
    final index = state.batches.indexWhere((b) => b.id == item.batchId);
    if (index >= 0) {
      if (!state.batches[index].itemIds.contains(item.id)) {
        state = state.copyWith(
          batches: [
            for (final batch in state.batches)
              batch.id == item.batchId
                  ? batch.copyWith(itemIds: [...batch.itemIds, item.id])
                  : batch,
          ],
        );
      }
    } else {
      _appendBatch(
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

  Future<void> _checkpointAll() => _checkpointing ??= _doCheckpointAll()
      .whenComplete(() => _checkpointing = null);

  Future<void> _doCheckpointAll() async {
    for (final entry in _torrentDownloads.entries.toList()) {
      try {
        if (!identical(_torrentDownloads[entry.key], entry.value)) continue;
        await _saveTorrent(entry.key, entry.value);
      } on Object catch (e, st) {
        _reportPersistenceError(e, st);
      }
    }
    for (final runtime in _httpDownloads.values.toList()) {
      try {
        await runtime.download.checkpoint();
      } on Object catch (e, st) {
        _reportPersistenceError(e, st);
      }
    }
    await _saveQueue();
  }

  void _invalidateRecovery(String id) {
    _generations[id] = (_generations[id] ?? 0) + 1;
    _retryTimers.remove(id)?.cancel();
  }

  bool _currentAttempt(String id, int generation) =>
      !_closing &&
      (_generations[id] ?? 0) == generation &&
      _findItem(id) != null &&
      !_findItem(id)!.status.isTerminal &&
      !_userPaused.contains(id);
}
