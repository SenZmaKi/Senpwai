import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/download/download_config.dart';
import 'package:senpwai/shared/net/download/http_checkpoint.dart';
import 'package:senpwai/shared/persistence/json_file_store.dart';
import 'package:senpwai/shared/net/download/download_state.dart';
import 'package:senpwai/shared/net/download/download_throttler.dart';
import 'package:senpwai/shared/net/download/shared.dart';
import 'package:senpwai/shared/net/interceptors/connectivity.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/net/net_config.dart';

part 'download_target.dart';

final log = Logger("senpwai.shared.net.download.download");

enum _RangeRequestSupport { supported, unsupported }

Map<String, dynamic> _downloadRequestExtra() => {
  skipConnectivityErrorTypesExtraKey: [
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  ],
};

Map<String, dynamic> _downloadProbeRequestExtra() =>
    NetConfig.getInstance()
        .buildCacheOptions(policy: CachePolicy.noCache)
        .toExtra()
      ..addAll(_downloadRequestExtra());

class Download {
  final DownloadParams params;
  final config = DownloadConfig.getInstance();
  final Dio _dio;
  late final DownloadState state = DownloadState(params: params);
  Future<void>? _downloadFuture;
  _OffsetFileWriter? _targetWriter;
  int _activeKwikConnections = 0;
  final File? checkpointFile;
  final void Function(int bytes, String? restartReason)? onRestored;
  HttpCheckpoint? _checkpoint;
  Timer? _checkpointTimer;
  bool _preservePartial = false;
  bool _suspending = false;
  bool _publishedByThisAttempt = false;
  bool _discardRequested = false;
  String? _resource;
  Object? error;
  File get _payload => checkpointFile == null
      ? params.targetFile
      : File('${params.targetFile.path}.senpwai-part');

  Future<void> checkpoint() async {
    final writer = _targetWriter;
    if (writer == null || _checkpoint == null || checkpointFile == null) return;
    await writer.checkpoint(() => _checkpoint!.save());
  }

  Future<void> cancel() async {
    _discardRequested = true;
    _preservePartial = false;
    await state.cancel();
    await _downloadFuture;
    await _cleanup();
  }

  Future<void> suspend() async {
    _preservePartial = true;
    _suspending = true;
    await state.cancel();
    await _downloadFuture;
  }

  /// `If-Range` validator (ETag preferred, falling back to Last-Modified)
  /// captured from the first 206 response. Subsequent reconnects send this
  /// so the server returns 200 (and we abort) if the file has changed.
  String? _ifRangeValidator;

  Download({
    required this.params,
    required this._dio,
    this.checkpointFile,
    this.onRestored,
  });

  static Future<ResolvedDownloadTarget> probeSingleFile({
    required String url,
    Map<String, dynamic>? headers,
  }) async {
    final dio = GlobalDio.getInstance();
    final response = await dio.get<ResponseBody>(
      url,
      options: Options(
        headers: {
          ...?headers,
          // AnimeHeaven treats 0-0 as a full-file request; use two bytes.
          'Range': 'bytes=0-1',
          'Accept-Encoding': 'identity',
        },
        responseType: ResponseType.stream,
        validateStatus: (status) => status == 200 || status == 206,
        extra: _downloadProbeRequestExtra(),
      ),
    );
    try {
      final responseBody = response.data;
      if (responseBody == null) {
        throw const DownloadProbeException(
          'The server did not return a readable response body.',
        );
      }
      final contentRange = response.headers.value('content-range');
      final contentLength = response.headers.value(Headers.contentLengthHeader);
      final supportsRangeRequests = response.statusCode == 206;
      final sizeBytes = supportsRangeRequests
          ? _parseContentRangeSize(contentRange)
          : int.tryParse(contentLength ?? '');
      final encoding = response.headers.value('content-encoding');
      final type = response.headers.value('content-type')?.toLowerCase() ?? '';
      if (type.contains('text/html') ||
          (encoding != null && encoding != 'identity') ||
          (supportsRangeRequests &&
              contentRange != 'bytes 0-${sizeBytes == 1 ? 0 : 1}/$sizeBytes')) {
        throw const DownloadProbeException(
          'The source did not return the selected file.',
        );
      }
      if (sizeBytes == null || sizeBytes <= 0) {
        throw const DownloadProbeException(
          'Could not determine the final content length for this file.',
        );
      }
      if (_isKwikRequest(response.realUri, headers)) {
        log.infoWithMetadata(
          'Kwik range probe completed',
          metadata: {
            'host': response.realUri.host,
            'statusCode': response.statusCode,
            'contentRange': contentRange,
            'contentLength': contentLength,
            'supportsRangeRequests': supportsRangeRequests,
            'sizeBytes': sizeBytes,
            'contentType': response.headers.value(Headers.contentTypeHeader),
          },
        );
      }
      return ResolvedDownloadTarget(
        resolvedUrl: response.realUri.toString(),
        sizeBytes: sizeBytes,
        supportsRangeRequests: supportsRangeRequests,
        suggestedFileName: _contentDispositionFilename(
          response.headers.value('content-disposition'),
        ),
        contentType: response.headers.value(Headers.contentTypeHeader),
      );
    } finally {
      await _discardResponseBody(response);
    }
  }

  static Future<void> _discardResponseBody(
    Response<ResponseBody> response,
  ) async {
    await response.data?.stream.listen(null).cancel();
  }

  static int? _parseContentRangeSize(String? contentRange) {
    if (contentRange == null) return null;
    final match = RegExp(r'/(\d+)$').firstMatch(contentRange);
    final size = match?.group(1);
    return size == null ? null : int.tryParse(size);
  }

  static bool _isKwikUrl(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'kwik.cx' || host.endsWith('.kwik.cx');
  }

  static bool _isKwikRequest(Uri url, Map<String, dynamic>? headers) {
    if (_isKwikUrl(url)) return true;
    final referer = headers?.entries
        .firstWhereOrNull((entry) => entry.key.toLowerCase() == 'referer')
        ?.value;
    return referer is String && _isKwikUrl(Uri.tryParse(referer) ?? Uri());
  }

  bool get _isKwikDownload =>
      _isKwikRequest(Uri.parse(params.url), params.headers);

  static String? _contentDispositionFilename(String? contentDisposition) {
    if (contentDisposition == null) return null;
    final encodedMatch = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    final plainMatch = RegExp(
      r'filename\s*=\s*(?:"([^"]+)"|([^;\s]+))',
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    final value =
        encodedMatch?.group(1) ?? plainMatch?.group(1) ?? plainMatch?.group(2);
    if (value == null || value.trim().isEmpty) return null;
    try {
      return Uri.decodeComponent(value.trim());
    } on ArgumentError {
      return value.trim();
    }
  }

  static List<({int startOffsetBytes, int lengthBytes})> computePartRanges({
    required int sizeBytes,
    required int numberOfParts,
  }) {
    final minimumBytesPerPart = sizeBytes ~/ numberOfParts;
    final partsWithOneExtraByte = sizeBytes % numberOfParts;
    var nextPartStartOffset = 0;
    final partRanges = <({int startOffsetBytes, int lengthBytes})>[];

    for (var partIndex = 0; partIndex < numberOfParts; partIndex++) {
      final bytesForPart =
          minimumBytesPerPart + (partIndex < partsWithOneExtraByte ? 1 : 0);
      if (bytesForPart <= 0) continue;

      partRanges.add((
        startOffsetBytes: nextPartStartOffset,
        lengthBytes: bytesForPart,
      ));
      nextPartStartOffset += bytesForPart;
    }
    return partRanges;
  }

  Future<void> _downloadPart({
    required int partNumber,
    required int startOffsetBytes,
    required int lengthBytes,
    required _RangeRequestSupport rangeRequestSupport,
  }) async {
    var currentOffset = startOffsetBytes;
    var remainingBytes = lengthBytes;

    while (remainingBytes > 0 && !state.isTerminal) {
      if (state.isPaused) await _waitForResume(partNumber);
      try {
        final processedCount = await _runDownloadIteration(
          partNumber: partNumber,
          offset: currentOffset,
          length: remainingBytes,
          rangeRequestSupport: rangeRequestSupport,
        );

        if (processedCount == 0 && !state.isPaused && !state.isTerminal) {
          throw const DownloadResourceChangedException(
            'The server returned an empty or truncated response.',
          );
        }
        currentOffset += processedCount;
        remainingBytes -= processedCount;

        if (state.isPaused && remainingBytes > 0) {
          await _waitForResume(partNumber);
        }
      } on DioException {
        rethrow;
      }
    }
  }

  Future<void> _waitForResume(int partNumber) async {
    final status = await state.waitTillStatus(
      statuses: [
        DownloadStatus.downloading,
        ...DownloadStatusExtension.terminalStatuses,
      ],
    );
    if (status != DownloadStatus.downloading) {
      throw DownloadCancelledException("Resume aborted. Status: $status");
    }
  }

  /// Handles the actual connection and data streaming for a single attempt.
  Future<int> _runDownloadIteration({
    required int partNumber,
    required int offset,
    required int length,
    required _RangeRequestSupport rangeRequestSupport,
  }) async {
    StreamSubscription<Uint8List>? subscription;
    int bytes = 0;
    String? firstChunkFingerprint;
    final targetWriter =
        _targetWriter ??
        (throw StateError('The download target writer is not open.'));
    final iterToken = state.registerIterationToken(
      partNumber,
      cancelOnPause: rangeRequestSupport == _RangeRequestSupport.supported,
    );
    final isKwikDownload = _isKwikDownload;
    if (isKwikDownload) {
      _activeKwikConnections += 1;
    }

    try {
      final response = await _establishConnection(
        offset,
        length,
        iterToken,
        rangeRequestSupport,
      );

      final expectedStatus =
          rangeRequestSupport == _RangeRequestSupport.supported ? 206 : 200;
      if (response.statusCode != expectedStatus) {
        await _discardResponseBody(response);
        throw DownloadResourceChangedException(
          "Expected $expectedStatus, got ${response.statusCode}. "
          "The file may have changed on the server during the download.",
        );
      }

      var expectedResponseBytes = length;
      if (rangeRequestSupport == _RangeRequestSupport.supported) {
        final expectedEnd = offset + length - 1;
        final contentRange = response.headers.value('content-range');
        final match = RegExp(
          r'^bytes (\d+)-(\d+)/(\d+)$',
          caseSensitive: false,
        ).firstMatch(contentRange ?? '');
        final actualStart = int.tryParse(match?.group(1) ?? '');
        final actualEnd = int.tryParse(match?.group(2) ?? '');
        final actualSize = int.tryParse(match?.group(3) ?? '');
        if (actualStart != offset ||
            actualEnd == null ||
            actualEnd < offset ||
            actualEnd > expectedEnd ||
            actualSize != params.sizeBytes) {
          await _discardResponseBody(response);
          throw DownloadResourceChangedException(
            'Expected Content-Range to start at $offset, end no later than '
            '$expectedEnd, and report size ${params.sizeBytes}; got '
            '${contentRange ?? 'none'}.',
          );
        }
        expectedResponseBytes = actualEnd - offset + 1;
      }

      if (isKwikDownload) {
        log.infoWithMetadata(
          'Kwik part connection established',
          metadata: {
            'fileName': params.targetFile.uri.pathSegments.last,
            'part': partNumber,
            'activeConnectionsForFile': _activeKwikConnections,
            'configuredParts': params.numberOfParts,
            'requestedRange': _requestedRange(
              offset,
              length,
              rangeRequestSupport,
            ),
            'statusCode': response.statusCode,
            'contentRange': response.headers.value('content-range'),
            'contentLength': response.headers.value(
              Headers.contentLengthHeader,
            ),
            'contentType': response.headers.value(Headers.contentTypeHeader),
            'server': response.headers.value('server'),
            'via': response.headers.value('via'),
          },
        );
      }

      final encoding = response.headers.value('content-encoding');
      if (response.realUri.toString() != _resource ||
          (encoding != null && encoding != 'identity')) {
        await _discardResponseBody(response);
        throw const DownloadResourceChangedException(
          'The server returned a different representation.',
        );
      }
      if (_ifRangeValidator != null &&
          HttpCheckpoint.strongEtag(response.headers.value('etag')) !=
              _ifRangeValidator) {
        await _discardResponseBody(response);
        throw const DownloadResourceChangedException(
          'The remote file identity changed.',
        );
      }

      final throttledStream = DownloadThrottler.getInstance()
          .getThrottledStream(response);

      final completer = Completer<void>();
      subscription = throttledStream.listen(
        (data) async {
          if (iterToken.isCancelled || state.isTerminal) return;

          subscription?.pause();
          try {
            if (state.isPaused &&
                rangeRequestSupport == _RangeRequestSupport.unsupported) {
              await _waitForResume(partNumber);
            }
            if (iterToken.isCancelled || state.isTerminal) return;

            final remainingBytes = expectedResponseBytes - bytes;
            if (data.length > remainingBytes) {
              throw DownloadResourceChangedException(
                'Response exceeded its declared range of '
                '$expectedResponseBytes bytes.',
              );
            }

            await targetWriter.writeAt(offset + bytes, data, () {
              final part = _checkpoint?.parts[partNumber - 1];
              if (part != null) part.record(offset + bytes, data);
            });

            firstChunkFingerprint ??= _fingerprint(data);

            state.addProgress(
              DownloadProgress(
                partNumber: partNumber,
                bytesDownloaded: data.length,
              ),
            );

            bytes += data.length;
          } catch (error, stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
            await subscription?.cancel();
            return;
          }
          subscription?.resume();
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object e, StackTrace st) {
          if (!completer.isCompleted) completer.completeError(e, st);
        },
        cancelOnError: true,
      );

      state.registerPart(partNumber, subscription, completer);
      await completer.future;

      if (isKwikDownload) {
        log.infoWithMetadata(
          'Kwik part connection completed',
          metadata: {
            'fileName': params.targetFile.uri.pathSegments.last,
            'part': partNumber,
            'requestedRange': _requestedRange(
              offset,
              length,
              rangeRequestSupport,
            ),
            'receivedBytes': bytes,
            'expectedBytes': length,
            'byteCountMatches': bytes == length,
            'firstChunkFingerprint': firstChunkFingerprint,
          },
        );
      }

      if (!state.isTerminal &&
          !state.isPaused &&
          bytes != expectedResponseBytes) {
        throw const DownloadResourceChangedException(
          'The server ended the transfer before its declared length.',
        );
      }
      return bytes;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return bytes;
      }
      rethrow;
    } finally {
      await subscription?.cancel();
      state.unregisterPart(partNumber);
      state.unregisterIterationToken(partNumber);
      if (isKwikDownload) {
        _activeKwikConnections -= 1;
      }
    }
  }

  String _requestedRange(
    int offset,
    int length,
    _RangeRequestSupport rangeRequestSupport,
  ) => rangeRequestSupport == _RangeRequestSupport.supported
      ? 'bytes=$offset-${offset + length - 1}'
      : 'full file';

  String _fingerprint(Uint8List data) {
    final sampleLength = data.length < 16 ? data.length : 16;
    return data
        .take(sampleLength)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Helper to configure the Dio request for a specific range.
  Future<Response<ResponseBody>> _establishConnection(
    int offset,
    int length,
    CancelToken cancelToken,
    _RangeRequestSupport rangeRequestSupport,
  ) {
    final headers = <String, dynamic>{
      ...params.headers,
      'Accept-Encoding': 'identity',
    };
    if (rangeRequestSupport == _RangeRequestSupport.supported &&
        _ifRangeValidator == null &&
        offset !=
            (_checkpoint?.parts
                    .firstWhere((p) => offset >= p.start && offset < p.end)
                    .start ??
                0)) {
      throw const DownloadResourceChangedException(
        'This server cannot safely resume partial bytes.',
      );
    }
    if (rangeRequestSupport == _RangeRequestSupport.supported) {
      final end = offset + length - 1;
      headers["Range"] = "bytes=$offset-$end";
    }
    if (rangeRequestSupport == _RangeRequestSupport.supported &&
        _ifRangeValidator != null) {
      headers["If-Range"] = _ifRangeValidator!;
    }
    return _dio.get<ResponseBody>(
      params.url,
      options: Options(
        headers: headers,
        responseType: ResponseType.stream,
        // Accept 200/206/416 so we can handle non-206 ourselves rather than
        // letting Dio throw a generic badResponse.
        validateStatus: (status) =>
            status == 200 || status == 206 || status == 416,
        extra: _downloadProbeRequestExtra(),
      ),
      cancelToken: cancelToken,
    );
  }

  Future<void> startAndWait() {
    if (_downloadFuture != null) {
      return _downloadFuture!;
    }
    _downloadFuture = _internalStartAndWait();
    return _downloadFuture!;
  }

  Future<void> _internalStartAndWait() async {
    if (state.isTerminal) {
      await _cleanup();
      return;
    }
    state.updateToDownloading();
    try {
      final saved = checkpointFile == null
          ? null
          : await HttpCheckpoint.load(checkpointFile!, params.targetFile.path);
      // A completed checkpoint is written before publication. This also
      // recovers termination between renaming the payload and saving queue state.
      if (saved?.complete == true &&
          saved!.size == params.sizeBytes &&
          await saved.verify(
            params.targetFile,
            shouldContinue: () => !state.isTerminal,
          )) {
        onRestored?.call(saved.size, null);
        state.finalize(DownloadStatus.completed);
        return;
      }
      if (saved?.complete == true &&
          saved!.size == params.sizeBytes &&
          !await params.targetFile.exists() &&
          await saved.verify(
            _payload,
            shouldContinue: () => !state.isTerminal,
          )) {
        if (state.isTerminal) {
          throw DownloadCancelledException('Download stopped');
        }
        await _payload.rename(params.targetFile.path);
        _publishedByThisAttempt = true;
        onRestored?.call(saved.size, null);
        state.finalize(DownloadStatus.completed);
        return;
      }
      final support = await _probeRangeRequestSupport();
      if (state.isTerminal) {
        throw DownloadCancelledException('Download stopped');
      }
      await _prepareTargetFile(saved, support);
      if (state.isTerminal) {
        throw DownloadCancelledException('Download stopped');
      }
      _checkpointTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        unawaited(
          checkpoint().catchError((Object e, StackTrace st) {
            log.warning('Could not checkpoint HTTP progress', e, st);
          }),
        );
      });
      state.startRateTracking();
      final parts = _checkpoint!.parts;
      await Future.wait([
        for (var i = 0; i < parts.length; i++)
          _downloadPart(
            partNumber: i + 1,
            startOffsetBytes: parts[i].start + parts[i].done,
            lengthBytes: parts[i].end - parts[i].start - parts[i].done,
            rangeRequestSupport: support,
          ),
      ]);
      if (state.isTerminal || _suspending) {
        throw DownloadCancelledException('Download stopped');
      }
      if (parts.any((p) => p.done != p.end - p.start)) {
        throw const DownloadResourceChangedException('The file is incomplete.');
      }
      _checkpoint!.complete = true;
      await checkpoint();
      await _closeTargetWriter();
      if (state.isTerminal) {
        throw DownloadCancelledException('Download stopped');
      }
      if (checkpointFile != null) {
        if (await params.targetFile.exists()) {
          throw const DownloadResourceChangedException(
            'The destination already contains another file.',
          );
        }
        if (state.isTerminal) {
          throw DownloadCancelledException('Download stopped');
        }
        await _payload.rename(params.targetFile.path);
        _publishedByThisAttempt = true;
      }
      state.finalize(DownloadStatus.completed);
    } on DownloadCancelledException {
      // Cancel and shutdown retain their own user intent in the queue.
    } catch (e, st) {
      if (!state.isCancelled) {
        error = e;
        log.warning('Download failed (${e.runtimeType})', null, st);
        // Cancel sibling connections before closing the writer. Failure retains
        // the payload, whereas an explicit user cancellation deletes it.
        _preservePartial = true;
        await state.abort(DownloadStatus.failed);
      }
    } finally {
      _checkpointTimer?.cancel();
      try {
        await checkpoint();
      } finally {
        await _closeTargetWriter();
        await _cleanup();
      }
    }
  }
}

/// Serializes offset-based writes through one file handle so range workers
/// cannot truncate the shared target or race its mutable file position.
class _OffsetFileWriter {
  final RandomAccessFile _file;
  Future<void> _pendingWrite = Future.value();
  bool _isClosed = false;

  _OffsetFileWriter(this._file);

  Future<void> writeAt(int offset, Uint8List data, void Function() committed) {
    if (_isClosed) {
      return Future.error(StateError('The download target writer is closed.'));
    }

    final write = _pendingWrite.then((_) async {
      await _file.setPosition(offset);
      await _file.writeFrom(data);
      committed();
    });
    _pendingWrite = write;
    return write;
  }

  Future<void> checkpoint(Future<void> Function() save) {
    if (_isClosed) return Future.value();
    final operation = _pendingWrite.then((_) async {
      await _file.flush();
      await save();
    });
    // A failed checkpoint must not poison subsequent payload writes.
    _pendingWrite = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    try {
      await _pendingWrite;
      await _file.flush();
    } finally {
      await _file.close();
    }
  }
}
