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

Map<String, dynamic> _downloadRequestExtra() =>
    NetConfig.getInstance()
        .buildCacheOptions(policy: CachePolicy.noCache)
        .toExtra()
      ..[skipConnectivityErrorTypesExtraKey] = [
        DioExceptionType.receiveTimeout,
      ];

class Download {
  final DownloadParams params;
  final config = DownloadConfig.getInstance();
  final _dio = GlobalDio.getInstance();
  late final DownloadState state = DownloadState(params: params);
  Future<void>? _downloadFuture;

  /// `If-Range` validator (ETag preferred, falling back to Last-Modified)
  /// captured from the first 206 response. Subsequent reconnects send this
  /// so the server returns 200 (and we abort) if the file has changed.
  String? _ifRangeValidator;

  Download({required this.params});

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
        extra: _downloadRequestExtra(),
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
      return ResolvedDownloadTarget(
        resolvedUrl: response.realUri.toString(),
        sizeBytes: sizeBytes,
        supportsRangeRequests: supportsRangeRequests,
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

    log.fine("Part $partNumber: Initializing at offset $currentOffset");

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
    log.fine("Part $partNumber: Paused, waiting for resume signal.");
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
    RandomAccessFile? raf;
    StreamSubscription<Uint8List>? subscription;
    int bytes = 0;
    final iterToken = state.registerIterationToken(
      partNumber,
      cancelOnPause: rangeRequestSupport == _RangeRequestSupport.supported,
    );

    try {
      raf = await params.targetFile.open(mode: FileMode.writeOnly);
      await raf.setPosition(offset);

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

          await raf?.writeFrom(data);

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

      return bytes;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return bytes;
      }
      rethrow;
    } finally {
      await subscription?.cancel();
      await raf?.close();
      state.unregisterPart(partNumber);
      state.unregisterIterationToken(partNumber);
    }
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
      log.fine("startAndWait() noop: already started");
      return _downloadFuture!;
    }
    _downloadFuture = _internalStartAndWait();
    return _downloadFuture!;
  }

  Future<void> _internalStartAndWait() async {
    state.updateToDownloading();

    log.infoWithMetadata("Starting download", metadata: {"params": params});
    final stopWatch = Stopwatch()..start();

    try {
      await _prepareTargetFile();

      final rangeRequestSupport = await _probeRangeRequestSupport();
      final numberOfParts =
          rangeRequestSupport == _RangeRequestSupport.supported
          ? params.numberOfParts
          : 1;
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
      state.finalize(DownloadStatus.completed);
    } on DownloadCancelledException {
      // State already finalized by cancel()
    } catch (e, st) {
      log.severeWithMetadata("Download failed", error: e, stackTrace: st);
      state.finalize(DownloadStatus.failed);
    } finally {
      stopWatch.stop();
    }

    await _cleanup();
    log.infoWithMetadata(
      "Download finished",
      metadata: {"status": state.status, "elapsed": stopWatch.elapsed},
    );
  }

  Future<void> _prepareTargetFile() async {
    if (!await params.downloadDirectory.exists()) {
      await params.downloadDirectory.create(recursive: true);
    }
    if (await params.targetFile.exists()) {
      await params.targetFile.delete();
    }
    final raf = await params.targetFile.open(mode: FileMode.write);
    await raf.truncate(params.sizeBytes);
    await raf.close();
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
