import 'dart:io';

import 'package:senpwai/shared/persistence/app_paths.dart';

class AppStorageUsage {
  final int imageCacheBytes;
  final int httpCacheBytes;
  final int cloudflareSessionBytes;
  final int appCacheAndSessionBytes;

  const AppStorageUsage({
    required this.imageCacheBytes,
    required this.httpCacheBytes,
    required this.cloudflareSessionBytes,
    required this.appCacheAndSessionBytes,
  });
}

Future<AppStorageUsage> calculateAppStorageUsage(AppPaths paths) async {
  final imageCacheBytes = await _sumPaths([
    paths.imageCacheDirectory,
    paths.imageCacheMetadataDirectory,
  ]);
  final httpCacheBytes = await _directorySize(paths.networkDioCacheDirectory);
  final cloudflareSessionBytes = await _sumPaths([
    paths.cfSessionsFile,
    paths.networkCookiesDirectory,
  ]);
  return AppStorageUsage(
    imageCacheBytes: imageCacheBytes,
    httpCacheBytes: httpCacheBytes,
    cloudflareSessionBytes: cloudflareSessionBytes,
    appCacheAndSessionBytes:
        imageCacheBytes + httpCacheBytes + cloudflareSessionBytes,
  );
}

Future<int> _sumPaths(Iterable<FileSystemEntity> entities) async {
  var total = 0;
  for (final entity in entities) {
    if (entity is File) {
      if (await entity.exists()) total += await entity.length();
    } else if (entity is Directory) {
      total += await _directorySize(entity);
    }
  }
  return total;
}

Future<int> _directorySize(Directory directory) async {
  if (!await directory.exists()) return 0;
  var total = 0;
  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is File) {
      try {
        total += await entity.length();
      } on FileSystemException {
        // Ignore files that disappear while calculating usage.
      }
    }
  }
  return total;
}
