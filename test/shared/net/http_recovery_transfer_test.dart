import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/shared/net/download/download.dart';
import 'package:senpwai/shared/net/download/http_checkpoint.dart';
import 'package:senpwai/shared/net/download/shared.dart';
import 'package:senpwai/shared/persistence/json_file_store.dart';

void main() {
  test(
    'cancellation before startup prevents HTTP work and file creation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cancel-before-start-',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final dio = Dio();
      var requests = 0;
      server.listen((request) async {
        requests++;
        request.response.statusCode = 500;
        await request.response.close();
      });
      try {
        final target = File('${directory.path}/file.bin');
        final checkpoint = File('${directory.path}/checkpoint.json');
        final download = Download(
          dio: dio,
          checkpointFile: checkpoint,
          params: DownloadParams(
            url: 'http://127.0.0.1:${server.port}/file',
            targetFile: target,
            sizeBytes: 4,
            numberOfParts: 1,
          ),
        );
        await download.cancel();
        await download.startAndWait().timeout(const Duration(seconds: 5));
        expect(download.state.isCancelled, isTrue);
        expect(requests, 0);
        expect(await target.exists(), isFalse);
        expect(await File('${target.path}.senpwai-part').exists(), isFalse);
        expect(await checkpoint.exists(), isFalse);
      } finally {
        dio.close(force: true);
        await server.close(force: true);
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'completed partial publishes without contacting an unavailable source',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'offline-publication-',
      );
      final dio = Dio();
      try {
        final target = File('${directory.path}/file.bin');
        final partial = File('${target.path}.senpwai-part');
        final checkpointFile = File('${directory.path}/checkpoint.json');
        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        await partial.writeAsBytes(bytes);
        final part = HttpPartCheckpoint(0, 4)..record(0, bytes);
        await HttpCheckpoint(
          store: JsonFileStore(checkpointFile),
          targetPath: target.path,
          resource: 'http://127.0.0.1:1/unavailable',
          etag: '"done"',
          size: 4,
          parts: [part],
          complete: true,
        ).save();
        final download = Download(
          dio: dio,
          checkpointFile: checkpointFile,
          params: DownloadParams(
            url: 'http://127.0.0.1:1/unavailable',
            targetFile: target,
            sizeBytes: 4,
            numberOfParts: 1,
          ),
        );
        await download.startAndWait().timeout(const Duration(seconds: 5));
        expect(download.error, isNull);
        expect(await target.readAsBytes(), bytes);
        expect(await partial.exists(), isFalse);
      } finally {
        dio.close(force: true);
        await directory.delete(recursive: true);
      }
    },
  );

  for (final scenario in [
    'unchanged',
    'changed-etag',
    'corrupt-local',
    'weak-etag',
  ]) {
    test('real HTTP recovery: $scenario', () async {
      final directory = await Directory.systemTemp.createTemp('http-recovery-');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final dio = Dio();
      final bytes = List<int>.generate(1024, (n) => n % 251);
      final ranges = <String>[];
      final url = 'http://127.0.0.1:${server.port}/file';
      server.listen((request) async {
        final range = request.headers.value('range')!;
        ranges.add(range);
        final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range)!;
        final start = int.parse(match[1]!);
        final end = int.parse(match[2]!);
        request.response.statusCode = 206;
        request.response.headers.set(
          'content-range',
          'bytes $start-$end/${bytes.length}',
        );
        request.response.headers.set(
          'etag',
          scenario == 'changed-etag'
              ? '"new"'
              : scenario == 'weak-etag'
              ? 'W/"old"'
              : '"old"',
        );
        request.response.contentLength = end - start + 1;
        request.response.add(bytes.sublist(start, end + 1));
        await request.response.close();
      });
      try {
        final target = File('${directory.path}/file.bin');
        final payload = File('${target.path}.senpwai-part');
        final checkpointFile = File('${directory.path}/checkpoint.json');
        final part = HttpPartCheckpoint(0, bytes.length);
        part.record(0, Uint8List.fromList(bytes.sublist(0, 256)));
        final local = [...bytes.sublist(0, 256), ...List.filled(768, 0)];
        if (scenario == 'corrupt-local') local[10] = 255;
        await payload.writeAsBytes(local);
        await HttpCheckpoint(
          store: JsonFileStore(checkpointFile),
          targetPath: target.path,
          resource: url,
          etag: '"old"',
          size: bytes.length,
          parts: [part],
        ).save();
        int? restoredBytes;
        String? reason;
        final download = Download(
          dio: dio,
          checkpointFile: checkpointFile,
          params: DownloadParams(
            url: url,
            targetFile: target,
            sizeBytes: bytes.length,
            numberOfParts: 1,
          ),
          onRestored: (count, message) {
            restoredBytes = count;
            reason = message;
          },
        );
        await download.startAndWait().timeout(const Duration(seconds: 10));
        expect(download.error, isNull);
        expect(await target.readAsBytes(), bytes);
        expect(await payload.exists(), isFalse);
        expect(restoredBytes, scenario == 'unchanged' ? 256 : 0);
        expect(reason, scenario == 'unchanged' ? isNull : isNotNull);
        expect(
          ranges,
          contains(scenario == 'unchanged' ? 'bytes=256-1023' : 'bytes=0-1023'),
        );
      } finally {
        dio.close(force: true);
        await server.close(force: true);
        await directory.delete(recursive: true);
      }
    });
  }
}
