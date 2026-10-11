part of 'download.dart';

extension _DownloadTarget on Download {
  Future<void> _prepareTargetFile(
    HttpCheckpoint? saved,
    _RangeRequestSupport support,
  ) async {
    await params.downloadDirectory.create(recursive: true);
    if (checkpointFile != null && await params.targetFile.exists()) {
      throw const DownloadResourceChangedException(
        'The destination already contains another file.',
      );
    }
    final hadPartial = await _payload.exists();
    final reusable =
        saved != null &&
        saved.canResume &&
        saved.size == params.sizeBytes &&
        saved.etag == _ifRangeValidator &&
        saved.resource == _resource &&
        support == _RangeRequestSupport.supported &&
        await saved.verify(_payload, shouldContinue: () => !state.isTerminal);
    if (state.isTerminal) throw DownloadCancelledException('Download stopped');
    if (reusable) {
      _checkpoint = saved;
      _checkpoint!.complete = false;
    } else {
      // Without a strong validator use one connection. Parallel requests
      // cannot otherwise prove they refer to the same representation.
      final count =
          support == _RangeRequestSupport.supported && _ifRangeValidator != null
          ? params.numberOfParts.clamp(1, 64)
          : 1;
      _checkpoint = HttpCheckpoint(
        store: JsonFileStore(
          checkpointFile ?? File('${_payload.path}.checkpoint'),
        ),
        targetPath: params.targetFile.path,
        resource: _resource!,
        etag: _ifRangeValidator,
        size: params.sizeBytes,
        parts:
            Download.computePartRanges(
                  sizeBytes: params.sizeBytes,
                  numberOfParts: count,
                )
                .map(
                  (r) => HttpPartCheckpoint(
                    r.startOffsetBytes,
                    r.startOffsetBytes + r.lengthBytes,
                  ),
                )
                .toList(),
      );
    }
    onRestored?.call(
      _checkpoint!.bytes,
      !reusable && ((saved?.bytes ?? 0) > 0 || hadPartial)
          ? 'The previous file could not be safely verified; restarting from zero.'
          : null,
    );
    final raf = await _payload.open(
      mode: reusable ? FileMode.append : FileMode.write,
    );
    try {
      await raf.truncate(params.sizeBytes);
      _targetWriter = _OffsetFileWriter(raf);
      if (checkpointFile != null) await checkpoint();
    } catch (_) {
      await raf.close();
      _targetWriter = null;
      rethrow;
    }
  }

  Future<void> _closeTargetWriter() async {
    final writer = _targetWriter;
    if (writer == null) return;
    _targetWriter = null;
    await writer.close();
  }

  Future<_RangeRequestSupport> _probeRangeRequestSupport() async {
    final token = state.registerIterationToken(0, cancelOnPause: false);
    try {
      final response = await _dio.get<ResponseBody>(
        params.url,
        cancelToken: token,
        options: Options(
          headers: {
            ...params.headers,
            // Match the planning probe: 0-0 returns the full file on AnimeHeaven.
            'Range': 'bytes=0-1',
            'Accept-Encoding': 'identity',
          },
          responseType: ResponseType.stream,
          validateStatus: (s) => s == 200 || s == 206,
          extra: _downloadProbeRequestExtra(),
        ),
      );
      try {
        final contentType =
            response.headers.value('content-type')?.toLowerCase() ?? '';
        final encoding = response.headers.value('content-encoding');
        if (contentType.contains('text/html') ||
            (encoding != null && encoding != 'identity')) {
          throw const DownloadResourceChangedException(
            'The server returned a page instead of the selected file.',
          );
        }
        final ranges = response.statusCode == 206;
        final size = ranges
            ? Download._parseContentRangeSize(
                response.headers.value('content-range'),
              )
            : int.tryParse(response.headers.value('content-length') ?? '');
        if (size != params.sizeBytes ||
            (ranges &&
                response.headers.value('content-range') !=
                    'bytes 0-${size == 1 ? 0 : 1}/$size')) {
          throw const DownloadResourceChangedException(
            'The remote size or byte range changed.',
          );
        }
        _resource = response.realUri.toString();
        _ifRangeValidator = HttpCheckpoint.strongEtag(
          response.headers.value('etag'),
        );
        return ranges
            ? _RangeRequestSupport.supported
            : _RangeRequestSupport.unsupported;
      } finally {
        await Download._discardResponseBody(response);
      }
    } finally {
      state.unregisterIterationToken(0);
    }
  }

  Future<void> _cleanup() async {
    if (_discardRequested || (state.isCancelled && !_preservePartial)) {
      try {
        if (await _payload.exists()) await _payload.delete();
        if (_publishedByThisAttempt && await params.targetFile.exists()) {
          await params.targetFile.delete();
        }
        if (checkpointFile != null) {
          for (final file in [
            checkpointFile!,
            File('${checkpointFile!.path}.bak'),
          ]) {
            if (await file.exists()) await file.delete();
          }
        }
      } on PathAccessException {
        log.warning("Could not delete partial file: ${params.targetFile}");
      }
    }
  }
}
