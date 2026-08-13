import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/download/download_config.dart';
import 'package:senpwai/shared/net/download/download_state.dart';
import 'package:senpwai/shared/net/download/download_throttler.dart';
import 'package:senpwai/shared/net/download/shared.dart';
import 'package:senpwai/shared/net/interceptors/connectivity.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/net/net_config.dart';

final log = Logger("senpwai.shared.net.download.download");

enum _RangeRequestSupport { supported, unsupported }

Map<String, dynamic> _downloadRequestExtra() => {
  skipConnectivityErrorTypesExtraKey: [DioExceptionType.receiveTimeout],
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

  /// `If-Range` validator (ETag preferred, falling back to Last-Modified)
  /// captured from the first 206 response. Subsequent reconnects send this
  /// so the server returns 200 (and we abort) if the file has changed.
  String? _ifRangeValidator;

  Download({required this.params, required Dio dio}) : _dio = dio;

  static Future<ResolvedDownloadTarget> probeSingleFile({
    required String url,
    Map<String, dynamic>? headers,
  }) async {
    final dio = GlobalDio.getInstance();
    final response = await dio.get<ResponseBody>(
      url,
      options: Options(
        headers: {'Range': 'bytes=0-0', ...?headers},
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
      try {
        final processedCount = await _runDownloadIteration(
          partNumber: partNumber,
          offset: currentOffset,
          length: remainingBytes,
          rangeRequestSupport: rangeRequestSupport,
        );

        currentOffset += processedCount;
        remainingBytes -= processedCount;

        if (state.isPaused && remainingBytes > 0) {
          await _waitForResume(partNumber);
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.receiveTimeout) {
          await _handleTimeoutAndPause(partNumber);
          continue;
        }
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

      if (rangeRequestSupport == _RangeRequestSupport.supported) {
        _ifRangeValidator ??=
            response.headers.value('etag') ??
            response.headers.value('last-modified');
      }

      final throttledStream = DownloadThrottler.getInstance()
          .getThrottledStream(response);

      final completer = Completer<void>();
      subscription = throttledStream.listen(
        (data) async {
          if (iterToken.isCancelled || state.isTerminal) return;

          subscription?.pause();
          if (state.isPaused &&
              rangeRequestSupport == _RangeRequestSupport.unsupported) {
            await _waitForResume(partNumber);
          }
          if (iterToken.isCancelled || state.isTerminal) return;

          await targetWriter.writeAt(offset + bytes, data);

          firstChunkFingerprint ??= _fingerprint(data);

          state.addProgress(
            DownloadProgress(
              partNumber: partNumber,
              bytesDownloaded: data.length,
            ),
          );

          bytes += data.length;
          subscription?.resume();
        },
        onDone: completer.complete,
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
    final headers = <String, dynamic>{...params.headers};
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
        extra: _downloadRequestExtra(),
      ),
      cancelToken: cancelToken,
    );
  }

  Future<void> _handleTimeoutAndPause(int partNumber) async {
    log.warning(
      "Part $partNumber: Network idle. Standing by for resume signal.",
    );

    final status = await state.waitTillStatus();

    if (status != DownloadStatus.downloading) {
      throw DownloadCancelledException(
        "Resume aborted. System status: $status",
      );
    }
  }

  Future<void> startAndWait() {
    if (_downloadFuture != null) {
      return _downloadFuture!;
    }
    _downloadFuture = _internalStartAndWait();
    return _downloadFuture!;
  }

  Future<void> _internalStartAndWait() async {
    state.updateToDownloading();

    try {
      await _prepareTargetFile();

      final rangeRequestSupport = await _probeRangeRequestSupport();
      final numberOfParts =
          rangeRequestSupport == _RangeRequestSupport.supported
          ? params.numberOfParts
          : 1;
      if (_isKwikDownload) {
        log.infoWithMetadata(
          'Kwik download starting',
          metadata: {
            'fileName': params.targetFile.uri.pathSegments.last,
            'sizeBytes': params.sizeBytes,
            'rangeRequestsSupported':
                rangeRequestSupport == _RangeRequestSupport.supported,
            'configuredParts': params.numberOfParts,
            'activeParts': numberOfParts,
          },
        );
      }
      final partRanges = computePartRanges(
        sizeBytes: params.sizeBytes,
        numberOfParts: numberOfParts,
      );
      state.startRateTracking();

      final tasks = partRanges.mapIndexed(
        (idx, range) => _downloadPart(
          partNumber: idx + 1,
          startOffsetBytes: range.startOffsetBytes,
          lengthBytes: range.lengthBytes,
          rangeRequestSupport: rangeRequestSupport,
        ),
      );

      await Future.wait(tasks);
      await _closeTargetWriter();
      state.finalize(DownloadStatus.completed);
    } on DownloadCancelledException {
      // State already finalized by cancel()
    } catch (e, st) {
      log.severeWithMetadata("Download failed", error: e, stackTrace: st);
      state.finalize(DownloadStatus.failed);
    } finally {
      await _closeTargetWriter();
    }

    await _cleanup();
  }

  Future<void> _prepareTargetFile() async {
    if (!await params.downloadDirectory.exists()) {
      await params.downloadDirectory.create(recursive: true);
    }
    if (await params.targetFile.exists()) {
      await params.targetFile.delete();
    }
    final raf = await params.targetFile.open(mode: FileMode.write);
    try {
      await raf.truncate(params.sizeBytes);
      _targetWriter = _OffsetFileWriter(raf);
    } catch (_) {
      await raf.close();
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
    final response = await _dio.get<ResponseBody>(
      params.url,
      options: Options(
        headers: {"Range": "bytes=0-0", ...params.headers},
        responseType: ResponseType.stream,
        validateStatus: (status) => status == 200 || status == 206,
        extra: _downloadRequestExtra(),
      ),
    );
    try {
      if (response.statusCode == 206) return _RangeRequestSupport.supported;
      return _RangeRequestSupport.unsupported;
    } finally {
      await _discardResponseBody(response);
    }
  }

  Future<void> _cleanup() async {
    if (state.isCancelled) {
      try {
        if (await params.targetFile.exists()) {
          await params.targetFile.delete();
        }
      } on PathAccessException {
        log.warning("Could not delete partial file: ${params.targetFile}");
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

  Future<void> writeAt(int offset, Uint8List data) {
    if (_isClosed) {
      return Future.error(StateError('The download target writer is closed.'));
    }

    final write = _pendingWrite.then((_) async {
      await _file.setPosition(offset);
      await _file.writeFrom(data);
    });
    _pendingWrite = write;
    return write;
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
