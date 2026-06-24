import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/persistence/app_paths.dart';

void main() {
  test('calculates cache and session storage usage', () async {
    final root = await Directory.systemTemp.createTemp('senpwai-storage-');
    addTearDown(() => root.delete(recursive: true));
    final paths = await AppPaths.fromRootDirectory(root);
    await File(
      path.join(paths.imageCacheDirectory.path, 'cover.bin'),
    ).writeAsString('1234');
    await File(
      path.join(paths.networkDioCacheDirectory.path, 'http.bin'),
    ).writeAsString('123');
    await paths.cfSessionsFile.writeAsString('12');

    final usage = await calculateAppStorageUsage(paths);

    expect(usage.imageCacheBytes, greaterThanOrEqualTo(4));
    expect(usage.httpCacheBytes, 3);
    expect(usage.cloudflareSessionBytes, greaterThanOrEqualTo(2));
    expect(
      usage.appCacheAndSessionBytes,
      usage.imageCacheBytes +
          usage.httpCacheBytes +
          usage.cloudflareSessionBytes,
    );
  });
}
