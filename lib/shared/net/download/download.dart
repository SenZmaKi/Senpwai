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
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/net/net_config.dart';

final log = Logger("senpwai.shared.net.download.download");

class Download {
  final DownloadParams params;
  final config = DownloadConfig.getInstance();
  final _dio = GlobalDio.getInstance();
  late final DownloadState state = DownloadState(params: params);
  Future<void>? _downloadFuture;

  Download({required this.params});

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
        );

        currentOffset += processedCount;
        remainingBytes -= processedCount;
      } on DioException catch (e) {
        if (e.type == DioExceptionType.receiveTimeout) {
          await _handleTimeoutAndPause(partNumber);
          continue;
        }
        rethrow;
      }
    }
  }

  /// Handles the actual connection and data streaming for a single attempt.
  Future<int> _runDownloadIteration({
    required int partNumber,
    required int offset,
    required int length,
  }) async {
    RandomAccessFile? raf;
    StreamSubscription<Uint8List>? subscription;
    int bytes = 0;

    try {
      raf = await params.targetFile.open(mode: FileMode.writeOnly);
      await raf.setPosition(offset);

      final response = await _establishConnection(offset, length);
      final throttledStream = DownloadThrottler.getInstance()
          .getThrottledStream(response);

      final completer = Completer<void>();
      subscription = throttledStream.listen(
        (data) async {
          subscription?.pause();
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
        onError: completer.completeError,
        cancelOnError: true,
      );

      state.registerPart(partNumber, subscription, completer);
      await completer.future;

      return bytes;
    } finally {
      await subscription?.cancel();
      await raf?.close();
      state.unregisterPart(partNumber);
    }
  }

  /// Helper to configure the Dio request for a specific range.
  Future<Response<ResponseBody>> _establishConnection(int offset, int length) {
    final end = offset + length - 1;
    return _dio.get<ResponseBody>(
      params.url,
      options: Options(
        headers: {"Range": "bytes=$offset-$end"},
        responseType: ResponseType.stream,
        extra: NetConfig.getInstance()
            .buildCacheOptions(policy: CachePolicy.noCache)
            .toExtra(),
      ),
      cancelToken: state.cancelToken,
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

      final partRanges = computePartRanges(
        sizeBytes: params.sizeBytes,
        numberOfParts: params.numberOfParts,
      );
      state.startRateTracking();

      final tasks = partRanges.mapIndexed(
        (idx, range) => _downloadPart(
          partNumber: idx + 1,
          startOffsetBytes: range.startOffsetBytes,
          lengthBytes: range.lengthBytes,
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
