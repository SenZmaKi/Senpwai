import 'dart:async';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/download/download_state.dart';
import 'package:senpwai/shared/net/download/shared.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/net/net_config.dart';

final log = Logger("senpwai.shared.net.download.download");

class Download {
  final DownloadParams params;
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
    if (state.isTerminal) return;

    log.fine(
      "Downloading part $partNumber (offset=$startOffsetBytes, len=$lengthBytes)",
    );

    RandomAccessFile? raf;
    final completer = Completer<void>();
    try {
      raf = await params.targetFile.open(mode: FileMode.writeOnly);
      await raf.setPosition(startOffsetBytes);

      final endOffsetBytes = startOffsetBytes + lengthBytes - 1;
      final response = await _dio.get<ResponseBody>(
        params.url,
        options: Options(
          headers: {"Range": "bytes=$startOffsetBytes-$endOffsetBytes"},
          responseType: ResponseType.stream,
          extra: NetConfig.getInstance()
              // Don't cache binary data
              .buildCacheOptions(policy: CachePolicy.noCache)
              .toExtra(),
        ),
        cancelToken: state.cancelToken,
      );

      final subscription = response.data!.stream.listen(null);

      subscription.onData((data) async {
        if (state.isTerminal) {
          subscription.cancel();
          return;
        }
        state.updateRate(data.length);

        // Pause to prevent race condition with async write
        subscription.pause();
        try {
          await raf?.writeFrom(data);
          state.addProgress(
            DownloadProgress(
              partNumber: partNumber,
              bytesDownloaded: data.length,
            ),
          );
        } finally {
          subscription.resume();
        }
      });

      subscription.onDone(() {
        if (!completer.isCompleted) completer.complete();
      });

      subscription.onError((e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      });

      state.registerPart(partNumber, subscription, completer);
      await completer.future;
      log.fine("Completed part $partNumber");
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        log.fine("Part $partNumber cancelled");
        throw DownloadCancelledException("Part $partNumber cancelled by user");
      }
      log.severeWithMetadata(
        "Part $partNumber failed",
        error: e,
        metadata: {"partNumber": partNumber},
      );
      rethrow;
    } finally {
      await raf?.close();
      state.unregisterPart(partNumber);
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
