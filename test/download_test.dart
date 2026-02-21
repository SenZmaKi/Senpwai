import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/download/download.dart';
import 'package:senpwai/shared/net/download/shared.dart';
import 'package:senpwai/shared/net/download/download_state.dart';

import 'support/download_server.dart';
import 'support/progress_bar.dart';

late DownloadServer _server;
late List<int> _payload;
late String _payloadSha256;

Download _makeDownload(Directory tempDir, {int numberOfParts = 8}) {
  return Download(
    params: DownloadParams(
      url: _server.downloadUrl,
      title: 'artifact',
      fileExtension: 'bin',
      downloadDirectory: tempDir,
      sizeBytes: _payload.length,
      numberOfParts: numberOfParts,
    ),
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
    _payload = List<int>.generate(2 * 1024 * 1024, (index) => index % 251);
    _payloadSha256 = sha256.convert(_payload).toString();
    _server = DownloadServer(payload: _payload);
    await _server.start();
  });

  tearDownAll(() async {
    await _server.close();
  });

  group('computePartRanges', () {
    test('distributes divisible sizes evenly', () {
      final ranges = Download.computePartRanges(
        sizeBytes: 12,
        numberOfParts: 3,
      );
      expect(ranges.length, 3);
      expect(ranges[0], (startOffsetBytes: 0, lengthBytes: 4));
      expect(ranges[1], (startOffsetBytes: 4, lengthBytes: 4));
      expect(ranges[2], (startOffsetBytes: 8, lengthBytes: 4));
    });

    test('handles remainders without gaps', () {
      final ranges = Download.computePartRanges(
        sizeBytes: 10,
        numberOfParts: 3,
      );
      expect(ranges.length, 3);
      expect(ranges[0], (startOffsetBytes: 0, lengthBytes: 4));
      expect(ranges[1], (startOffsetBytes: 4, lengthBytes: 3));
      expect(ranges[2], (startOffsetBytes: 7, lengthBytes: 3));
    });

    test('skips empty parts when count exceeds size', () {
      final ranges = Download.computePartRanges(sizeBytes: 2, numberOfParts: 5);
      expect(ranges.length, 2);
      expect(ranges[0], (startOffsetBytes: 0, lengthBytes: 1));
      expect(ranges[1], (startOffsetBytes: 1, lengthBytes: 1));
    });

    test('single part covers entire file', () {
      final ranges = Download.computePartRanges(
        sizeBytes: 100,
        numberOfParts: 1,
      );
      expect(ranges.length, 1);
      expect(ranges[0], (startOffsetBytes: 0, lengthBytes: 100));
    });

    test('total bytes equals sizeBytes for any configuration', () {
      for (final sizeBytes in [1, 7, 100, 1000, 1048576]) {
        for (final parts in [1, 2, 3, 7, 16]) {
          final ranges = Download.computePartRanges(
            sizeBytes: sizeBytes,
            numberOfParts: parts,
          );
          final totalBytes = ranges.fold(0, (sum, r) => sum + r.lengthBytes);
          expect(totalBytes, sizeBytes, reason: 'size=$sizeBytes parts=$parts');
        }
      }
    });

    test('ranges are contiguous without overlap', () {
      final ranges = Download.computePartRanges(
        sizeBytes: 1000,
        numberOfParts: 7,
      );
      for (var i = 0; i < ranges.length - 1; i++) {
        final current = ranges[i];
        final next = ranges[i + 1];
        expect(
          current.startOffsetBytes + current.lengthBytes,
          next.startOffsetBytes,
          reason: 'Gap between part $i and ${i + 1}',
        );
      }
    });
  });

  group('DownloadState', () {
    test('initial status is idle', () {
      final state = DownloadState(
        params: DownloadParams(
          url: 'http://example.com/file.bin',
          title: 'test',
          fileExtension: 'bin',
          downloadDirectory: Directory.systemTemp,
          sizeBytes: 100,
          numberOfParts: 1,
        ),
      );
      expect(state.status, DownloadStatus.idle);
      expect(state.isStarted, false);
      expect(state.isPaused, false);
      expect(state.isCancelled, false);
      expect(state.isComplete, false);
    });

    test('pause/resume/cancel are noop when idle', () async {
      final state = DownloadState(
        params: DownloadParams(
          url: 'http://example.com/file.bin',
          title: 'test',
          fileExtension: 'bin',
          downloadDirectory: Directory.systemTemp,
          sizeBytes: 100,
          numberOfParts: 1,
        ),
      );
      state.pause();
      expect(state.status, DownloadStatus.idle);
      state.resume();
      expect(state.status, DownloadStatus.idle);
      await state.cancel();
      expect(state.status, DownloadStatus.idle);
    });
  });

  group('Download integration', () {
    test(
      'single-part download writes correct bytes',
      timeout: Timeout(Duration(minutes: 2)),
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'senpwai-dl-single-',
        );
        try {
          final download = _makeDownload(tempDir, numberOfParts: 1);
          await download.start();

          expect(download.state.status, DownloadStatus.completed);
          final bytes = await download.params.targetFile.readAsBytes();
          expect(bytes.length, _payload.length);
          expect(sha256.convert(bytes).toString(), _payloadSha256);
        } finally {
          await _deleteDirectoryWithRetry(tempDir);
        }
      },
    );

    test(
      'multi-part download writes expected artifact bytes',
      timeout: Timeout(Duration(minutes: 2)),
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'senpwai-dl-multi-',
        );
        try {
          final download = _makeDownload(tempDir, numberOfParts: 8);
          final progressBar = FillingBar(
            total: _payload.length,
            desc: 'multi-part download',
          );
          var totalDownloaded = 0;
          final sub = download.state.progress.listen((p) {
            totalDownloaded += p.bytesDownloaded;
            progressBar.update(totalDownloaded);
          }, onDone: progressBar.complete);

          await download.start();
          await sub.cancel();
          progressBar.complete();

          expect(download.state.status, DownloadStatus.completed);
          final bytes = await download.params.targetFile.readAsBytes();
          expect(bytes.length, _payload.length);
          expect(sha256.convert(bytes).toString(), _payloadSha256);
        } finally {
          await _deleteDirectoryWithRetry(tempDir);
        }
      },
    );

    test(
      'progress reports total bytes downloaded',
      timeout: Timeout(Duration(minutes: 2)),
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'senpwai-dl-progress-',
        );
        try {
          final download = _makeDownload(tempDir, numberOfParts: 4);
          var totalReported = 0;
          final sub = download.state.progress.listen((p) {
            totalReported += p.bytesDownloaded;
          });

          await download.start();
          await sub.cancel();

          expect(totalReported, _payload.length);
        } finally {
          await _deleteDirectoryWithRetry(tempDir);
        }
      },
    );

    test(
      'pause and resume temporarily halts then completes',
      timeout: Timeout(Duration(minutes: 2)),
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'senpwai-dl-pause-',
        );
        try {
          final download = _makeDownload(tempDir, numberOfParts: 1);
          final progressBar = FillingBar(
            total: _payload.length,
            desc: 'pause-resume',
          );
          var totalDownloaded = 0;
          final firstProgressCompleter = Completer<void>();

          final sub = download.state.progress.listen((p) {
            totalDownloaded += p.bytesDownloaded;
            progressBar.update(totalDownloaded);
            if (!firstProgressCompleter.isCompleted && totalDownloaded > 0) {
              firstProgressCompleter.complete();
            }
          }, onDone: progressBar.complete);

          download.start();
          await firstProgressCompleter.future.timeout(Duration(seconds: 15));

          download.state.pause();
          expect(download.state.status, DownloadStatus.paused);

          await Future<void>.delayed(Duration(milliseconds: 500));
          final bytesAfterPause = totalDownloaded;
          await Future<void>.delayed(Duration(milliseconds: 500));
          expect(
            totalDownloaded,
            bytesAfterPause,
            reason: 'bytes should not change while paused',
          );

          download.state.resume();
          expect(download.state.status, DownloadStatus.downloading);

          await download.state.waitTillFinished();
          await sub.cancel();
          progressBar.complete();

          expect(download.state.status, DownloadStatus.completed);
          final bytes = await download.params.targetFile.readAsBytes();
          expect(sha256.convert(bytes).toString(), _payloadSha256);
        } finally {
          await _deleteDirectoryWithRetry(tempDir);
        }
      },
    );

    test(
      'cancel stops download and removes partial file',
      timeout: Timeout(Duration(minutes: 2)),
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'senpwai-dl-cancel-',
        );
        try {
          final download = _makeDownload(tempDir, numberOfParts: 1);
          final firstProgressCompleter = Completer<void>();

          final sub = download.state.progress.listen((p) {
            if (!firstProgressCompleter.isCompleted) {
              firstProgressCompleter.complete();
            }
          });

          final startFuture = download.start();
          await firstProgressCompleter.future.timeout(Duration(seconds: 15));

          await download.state.cancel();
          expect(download.state.status, DownloadStatus.cancelled);

          // Wait for start() to complete (including cleanup)
          await startFuture;
          await sub.cancel();

          final fileExists = await download.params.targetFile.exists();
          expect(fileExists, false);
        } finally {
          await _deleteDirectoryWithRetry(tempDir);
        }
      },
    );

    test(
      'calling start twice is noop',
      timeout: Timeout(Duration(minutes: 2)),
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'senpwai-dl-double-start-',
        );
        try {
          final download = _makeDownload(tempDir, numberOfParts: 1);
          final future1 = download.start();
          final future2 = download.start();
          await Future.wait([future1, future2]);

          expect(download.state.status, DownloadStatus.completed);
          final bytes = await download.params.targetFile.readAsBytes();
          expect(sha256.convert(bytes).toString(), _payloadSha256);
        } finally {
          await _deleteDirectoryWithRetry(tempDir);
        }
      },
    );

    test(
      'creates download directory if missing',
      timeout: Timeout(Duration(minutes: 2)),
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'senpwai-dl-mkdir-',
        );
        final nestedDir = Directory('${tempDir.path}/nested/deep/dir');
        try {
          final download = Download(
            params: DownloadParams(
              url: _server.downloadUrl,
              title: 'artifact',
              fileExtension: 'bin',
              downloadDirectory: nestedDir,
              sizeBytes: _payload.length,
              numberOfParts: 2,
            ),
          );
          await download.start();

          expect(await nestedDir.exists(), true);
          expect(download.state.status, DownloadStatus.completed);
        } finally {
          await _deleteDirectoryWithRetry(tempDir);
        }
      },
    );
  });

  group('Download external', () {
    test(
      'downloads real file from external server',
      timeout: Timeout(Duration(minutes: 2)),
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'senpwai-dl-external-',
        );
        try {
          // Use Cloudflare's test file (100KB) - single part since it doesn't support Range
          const url = 'https://speed.cloudflare.com/__down?bytes=102400';
          const expectedSize = 102400;

          final download = Download(
            params: DownloadParams(
              url: url,
              title: 'external-test',
              fileExtension: 'bin',
              downloadDirectory: tempDir,
              sizeBytes: expectedSize,
              numberOfParts: 1, // Single part - server doesn't support Range
            ),
          );

          await download.start();

          expect(download.state.status, DownloadStatus.completed);
          final file = download.params.targetFile;
          expect(await file.exists(), true);
          final bytes = await file.readAsBytes();
          expect(bytes.length, expectedSize);
        } finally {
          await _deleteDirectoryWithRetry(tempDir);
        }
      },
    );

    test(
      'downloads real file with range requests',
      timeout: Timeout(Duration(minutes: 2)),
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'senpwai-dl-external-range-',
        );
        try {
          // Use jsDelivr CDN which supports Range requests
          const fontUrl =
              'https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/fonts/bootstrap-icons.woff2';

          // Get actual file size with HEAD request
          final headResponse = await HttpClient()
              .headUrl(Uri.parse(fontUrl))
              .then((req) => req.close());
          final expectedSize = headResponse.contentLength;
          expect(
            expectedSize,
            greaterThan(0),
            reason: 'HEAD request should return content length',
          );

          final download = Download(
            params: DownloadParams(
              url: fontUrl,
              title: 'external-range-test',
              fileExtension: 'woff2',
              downloadDirectory: tempDir,
              sizeBytes: expectedSize,
              numberOfParts: 4,
            ),
          );

          await download.start();

          expect(download.state.status, DownloadStatus.completed);
          final file = download.params.targetFile;
          expect(await file.exists(), true);
          final bytes = await file.readAsBytes();
          expect(bytes.length, expectedSize);
        } finally {
          await _deleteDirectoryWithRetry(tempDir);
        }
      },
    );
  });
}
