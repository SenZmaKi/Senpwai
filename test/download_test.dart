import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/download/download.dart';
import 'package:senpwai/shared/net/download/download_config.dart';
import 'package:senpwai/shared/net/download/download_rate_tracker.dart';
import 'package:senpwai/shared/net/download/download_state.dart';
import 'package:senpwai/shared/net/download/shared.dart';
import 'package:senpwai/shared/shared.dart' as shared;

import 'support/download_server.dart';
import 'support/progress_bar.dart';

late DownloadServer _server;
late List<int> _payload;
late String _payloadSha256;

DownloadState _newState() {
  return DownloadState(
    params: DownloadParams(
      url: 'http://example.com/file.bin',
      title: 'test',
      fileExtension: 'bin',
      downloadDirectory: Directory.systemTemp,
      sizeBytes: 100,
      numberOfParts: 1,
    ),
  );
}

Download _makeDownload(
  Directory downloadDirectory, {
  int numberOfParts = 8,
  String? url,
  int? sizeBytes,
  String title = 'artifact',
}) {
  return Download(
    params: DownloadParams(
      url: url ?? _server.downloadUrl,
      title: title,
      fileExtension: 'bin',
      downloadDirectory: downloadDirectory,
      sizeBytes: sizeBytes ?? _payload.length,
      numberOfParts: numberOfParts,
    ),
  );
}

Future<void> _withTempDirectory(
  String prefix,
  Future<void> Function(Directory tempDir) run,
) async {
  final tempDir = await Directory.systemTemp.createTemp(prefix);
  try {
    await run(tempDir);
  } finally {
    await _deleteDirectoryWithRetry(tempDir);
  }
}

Future<void> _expectPayloadMatchesFixture(Download download) async {
  final bytes = await download.params.targetFile.readAsBytes();
  expect(bytes.length, _payload.length);
  expect(sha256.convert(bytes).toString(), _payloadSha256);
}

void _printRate(double bytesPerSecond, double maxBytesPerSecond) {
  stdout.write(
    '\rCurr: ${(bytesPerSecond / shared.Constants.megaByte).toStringAsFixed(4)} MBps | '
    'Max: ${(maxBytesPerSecond / shared.Constants.megaByte).toStringAsFixed(4)} MBps',
  );
}

Future<void> _deleteDirectoryWithRetry(Directory directory) async {
  if (!await directory.exists()) return;
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      await directory.delete(recursive: true);
      return;
    } on PathAccessException {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }
}

void main() {
  setUpAll(() async {
    setupLogger();
    _payload = List<int>.generate(
      10 * shared.Constants.megaByte,
      (index) => index % 251,
    );
    _payloadSha256 = sha256.convert(_payload).toString();
    _server = DownloadServer(payload: _payload);
    await _server.start();
  });

  tearDown(() {
    DownloadConfig.getInstance().updateMaxBytesPerSecond(0);
  });

  tearDownAll(() async {
    await _server.close();
  });

  group('computePartRanges', () {
    test('splits bytes without gaps or overlap for edge cases', () {
      final cases = [
        (
          sizeBytes: 12,
          numberOfParts: 3,
          expected: [
            (startOffsetBytes: 0, lengthBytes: 4),
            (startOffsetBytes: 4, lengthBytes: 4),
            (startOffsetBytes: 8, lengthBytes: 4),
          ],
        ),
        (
          sizeBytes: 10,
          numberOfParts: 3,
          expected: [
            (startOffsetBytes: 0, lengthBytes: 4),
            (startOffsetBytes: 4, lengthBytes: 3),
            (startOffsetBytes: 7, lengthBytes: 3),
          ],
        ),
        (
          sizeBytes: 2,
          numberOfParts: 5,
          expected: [
            (startOffsetBytes: 0, lengthBytes: 1),
            (startOffsetBytes: 1, lengthBytes: 1),
          ],
        ),
        (
          sizeBytes: 100,
          numberOfParts: 1,
          expected: [(startOffsetBytes: 0, lengthBytes: 100)],
        ),
      ];

      for (final entry in cases) {
        final ranges = Download.computePartRanges(
          sizeBytes: entry.sizeBytes,
          numberOfParts: entry.numberOfParts,
        );
        expect(ranges, entry.expected);

        final totalBytes = ranges.fold(0, (sum, r) => sum + r.lengthBytes);
        expect(totalBytes, entry.sizeBytes);

        for (var i = 0; i < ranges.length - 1; i++) {
          expect(
            ranges[i].startOffsetBytes + ranges[i].lengthBytes,
            ranges[i + 1].startOffsetBytes,
          );
        }
      }
    });
  });

  group('DownloadState', () {
    test('starts idle with correct derived flags', () {
      final state = _newState();
      expect(state.status, DownloadStatus.idle);
      expect(state.isStarted, false);
      expect(state.isPaused, false);
      expect(state.isCancelled, false);
      expect(state.isComplete, false);
      expect(state.isTerminal, false);
    });

    test('pause/resume/cancel are noops while idle', () async {
      final state = _newState();
      state.pause();
      expect(state.status, DownloadStatus.idle);
      state.resume();
      expect(state.status, DownloadStatus.idle);
      await state.cancel();
      expect(state.status, DownloadStatus.idle);
    });

    test('pause/resume/cancel transitions for active download', () async {
      final state = _newState();
      final pausedFuture = state.waitTillStatus(
        statuses: [DownloadStatus.paused],
      );

      state.updateToDownloading();
      state.pause();
      expect(await pausedFuture, DownloadStatus.paused);

      state.resume();
      expect(state.status, DownloadStatus.downloading);

      await state.cancel();
      expect(state.status, DownloadStatus.cancelled);
      expect(state.isTerminal, true);
      expect(state.cancelToken.isCancelled, true);
    });
  });

  group('Download integration', () {
    test(
      'completes correctly for single and multipart downloads',
      timeout: Timeout(Duration(minutes: 2)),
      () async {
        for (final parts in [1, 4, 8]) {
          await _withTempDirectory('senpwai-dl-complete-$parts-', (
            tempDir,
          ) async {
            final download = _makeDownload(tempDir, numberOfParts: parts);
            await download.startAndWait();

            expect(download.state.status, DownloadStatus.completed);
            await _expectPayloadMatchesFixture(download);
          });
        }
      },
    );

    test(
      'progress sums to total bytes and renders MBps rate',
      timeout: Timeout(Duration(minutes: 2)),
      () async {
        await _withTempDirectory('senpwai-dl-progress-', (tempDir) async {
          final download = _makeDownload(tempDir, numberOfParts: 4);
          final progressBar = FillingBar(
            total: _payload.length,
            desc: 'download progress',
            rate: true,
          );

          var totalReported = 0;
          var sawPositiveRate = false;

          final progressSub = download.state.progressStream.listen((progress) {
            totalReported += progress.bytesDownloaded;
            progressBar.update(
              totalReported,
              bytesPerSecond: download.state.rateTracker.bytesPerSecond,
            );
          }, onDone: progressBar.complete);

          final rateSub = download.state.rateTracker.updateStream.listen((bps) {
            if (bps > 0) {
              sawPositiveRate = true;
            }
          });

          await download.startAndWait();
          await progressSub.cancel();
          await rateSub.cancel();
          progressBar.complete();

          expect(download.state.status, DownloadStatus.completed);
          expect(totalReported, _payload.length);
          expect(sawPositiveRate, true);
        });
      },
    );

    test(
      'download throttling',
      timeout: Timeout(Duration(minutes: 2)),
      () async {
        await _withTempDirectory('senpwai-dl-throttle-', (tempDir) async {
          final maxBytesPerSecond = 10.0 * shared.Constants.megaByte;
          DownloadConfig.getInstance().updateMaxBytesPerSecond(
            maxBytesPerSecond,
          );

          final download = _makeDownload(tempDir, numberOfParts: 4);
          var sawRateUpdate = false;

          final sub = DownloadRateTracker.globalUpdateStream.listen((bps) {
            if (bps <= 0) return;
            sawRateUpdate = true;

            const exceedAllowanceFactor = 1.5;
            expect(
              bps,
              lessThanOrEqualTo(maxBytesPerSecond * exceedAllowanceFactor),
            );
            _printRate(bps, maxBytesPerSecond);
          });

          stdout.write('\n');
          await download.startAndWait();
          stdout.write('\n');

          await sub.cancel();

          expect(download.state.status, DownloadStatus.completed);
          expect(sawRateUpdate, true);
          await _expectPayloadMatchesFixture(download);
        });
      },
    );

    test(
      'pause then resume halts and then completes',
      timeout: Timeout(Duration(minutes: 2)),
      () async {
        await _withTempDirectory('senpwai-dl-pause-', (tempDir) async {
          final download = _makeDownload(tempDir, numberOfParts: 1);
          final progressBar = FillingBar(
            total: _payload.length,
            desc: 'pause/resume',
            rate: true,
          );

          var totalDownloaded = 0;
          final firstProgress = Completer<void>();

          final progressSub = download.state.progressStream.listen((progress) {
            totalDownloaded += progress.bytesDownloaded;
            progressBar.update(
              totalDownloaded,
              bytesPerSecond: download.state.rateTracker.bytesPerSecond,
            );
            if (!firstProgress.isCompleted && totalDownloaded > 0) {
              firstProgress.complete();
            }
          }, onDone: progressBar.complete);

          final startFuture = download.startAndWait();
          await firstProgress.future.timeout(Duration(seconds: 15));

          download.state.pause();
          expect(download.state.status, DownloadStatus.paused);

          await Future<void>.delayed(Duration(milliseconds: 500));
          final bytesAfterPause = totalDownloaded;
          await Future<void>.delayed(Duration(milliseconds: 500));
          expect(totalDownloaded, bytesAfterPause);

          download.state.resume();
          expect(download.state.status, DownloadStatus.downloading);

          await startFuture;
          await progressSub.cancel();
          progressBar.complete();

          expect(download.state.status, DownloadStatus.completed);
          await _expectPayloadMatchesFixture(download);
        });
      },
    );

    test(
      'cancel stops download and removes partial file',
      timeout: Timeout(Duration(minutes: 2)),
      () async {
        await _withTempDirectory('senpwai-dl-cancel-', (tempDir) async {
          final download = _makeDownload(tempDir, numberOfParts: 1);
          final firstProgress = Completer<void>();

          final sub = download.state.progressStream.listen((_) {
            if (!firstProgress.isCompleted) {
              firstProgress.complete();
            }
          });

          final startFuture = download.startAndWait();
          await firstProgress.future.timeout(Duration(seconds: 15));

          await download.state.cancel();
          await startFuture;
          await sub.cancel();

          expect(download.state.status, DownloadStatus.cancelled);
          expect(await download.params.targetFile.exists(), false);
        });
      },
    );

    test(
      'second start returns same future and does not restart',
      timeout: Timeout(Duration(minutes: 2)),
      () async {
        await _withTempDirectory('senpwai-dl-double-start-', (tempDir) async {
          final download = _makeDownload(tempDir, numberOfParts: 1);
          final first = download.startAndWait();
          final second = download.startAndWait();

          expect(identical(first, second), true);
          await Future.wait([first, second]);

          expect(download.state.status, DownloadStatus.completed);
          await _expectPayloadMatchesFixture(download);
        });
      },
    );

    test(
      'creates download directory when missing',
      timeout: Timeout(Duration(minutes: 2)),
      () async {
        await _withTempDirectory('senpwai-dl-mkdir-', (tempDir) async {
          final nestedDir = Directory('${tempDir.path}/nested/deep/dir');
          final download = _makeDownload(nestedDir, numberOfParts: 2);

          await download.startAndWait();

          expect(await nestedDir.exists(), true);
          expect(download.state.status, DownloadStatus.completed);
          await _expectPayloadMatchesFixture(download);
        });
      },
    );

    test(
      'network errors transition download to failed status',
      timeout: Timeout(Duration(minutes: 2)),
      () async {
        await _withTempDirectory('senpwai-dl-failed-', (tempDir) async {
          final download = _makeDownload(
            tempDir,
            numberOfParts: 1,
            url: 'http://127.0.0.1:1/unreachable.bin',
            title: 'failed-artifact',
          );

          await download.startAndWait();

          expect(download.state.status, DownloadStatus.failed);
        });
      },
    );
  });
}
