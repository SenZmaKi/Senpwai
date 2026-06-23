import 'dart:convert';

import 'package:file/file.dart' as file;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/shared/persistence/app_paths.dart';

class AppImageCache {
  static const _cacheKey = 'senpwaiImageCache';
  static const maxCacheSizeBytes = 50 * 1024 * 1024;
  static CacheManager? _manager;

  AppImageCache._();

  static CacheManager get manager {
    final resolved = _manager;
    if (resolved == null) {
      throw StateError('AppImageCache.initialize must be called first.');
    }
    return resolved;
  }

  static void initialize(AppPaths paths) {
    _manager ??= CacheManager(
      Config(
        _cacheKey,
        stalePeriod: const Duration(days: 30),
        maxNrOfCacheObjects: 1 << 30,
        repo: _SizeLimitedCacheInfoRepository(
          delegate: JsonCacheInfoRepository(
            path: paths.imageCacheMetadataFile.path,
          ),
          cacheDirectoryPath: paths.imageCacheDirectory.path,
          metadataFilePath: paths.imageCacheMetadataFile.path,
          maxSizeBytes: maxCacheSizeBytes,
        ),
        fileSystem: _AbsoluteCacheFileSystem(paths.imageCacheDirectory.path),
      ),
    );
  }
}

class _SizeLimitedCacheInfoRepository implements CacheInfoRepository {
  static const LocalFileSystem _fileSystem = LocalFileSystem();

  final CacheInfoRepository delegate;
  final String cacheDirectoryPath;
  final String metadataFilePath;
  final int maxSizeBytes;

  const _SizeLimitedCacheInfoRepository({
    required this.delegate,
    required this.cacheDirectoryPath,
    required this.metadataFilePath,
    required this.maxSizeBytes,
  });

  @override
  Future<bool> exists() => delegate.exists();

  @override
  Future<bool> open() async {
    await _repairMalformedMetadataFile();
    return delegate.open();
  }

  @override
  Future<dynamic> updateOrInsert(CacheObject cacheObject) {
    return delegate.updateOrInsert(_withAbsolutePath(cacheObject));
  }

  @override
  Future<CacheObject> insert(
    CacheObject cacheObject, {
    bool setTouchedToNow = true,
  }) {
    return delegate.insert(
      _withAbsolutePath(cacheObject),
      setTouchedToNow: setTouchedToNow,
    );
  }

  @override
  Future<CacheObject?> get(String key) async {
    final object = await delegate.get(key);
    return object == null ? null : _withAbsolutePath(object);
  }

  @override
  Future<int> delete(int id) => delegate.delete(id);

  @override
  Future<int> deleteAll(Iterable<int> ids) => delegate.deleteAll(ids);

  @override
  Future<int> update(CacheObject cacheObject, {bool setTouchedToNow = true}) {
    return delegate.update(
      _withAbsolutePath(cacheObject),
      setTouchedToNow: setTouchedToNow,
    );
  }

  @override
  Future<List<CacheObject>> getAllObjects() async {
    final objects = await delegate.getAllObjects();
    return objects.map(_withAbsolutePath).toList();
  }

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) async {
    final objects = (await getAllObjects()).toList()
      ..sort((a, b) {
        final aTouched = a.touched ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTouched = b.touched ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTouched.compareTo(bTouched);
      });

    var totalBytes = 0;
    final lengths = <CacheObject, int>{};
    for (final object in objects) {
      final length = await _objectLength(object);
      lengths[object] = length;
      totalBytes += length;
    }

    if (totalBytes <= maxSizeBytes) {
      return const [];
    }

    final toRemove = <CacheObject>[];
    for (final object in objects) {
      toRemove.add(object);
      totalBytes -= lengths[object] ?? 0;
      if (totalBytes <= maxSizeBytes) break;
    }
    return toRemove;
  }

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) async {
    final objects = await delegate.getOldObjects(maxAge);
    return objects.map(_withAbsolutePath).toList();
  }

  @override
  Future<bool> close() => delegate.close();

  @override
  Future<void> deleteDataFile() => delegate.deleteDataFile();

  CacheObject _withAbsolutePath(CacheObject object) {
    final relativePath = object.relativePath;
    if (path.isAbsolute(relativePath)) return object;
    return object.copyWith(
      relativePath: path.join(cacheDirectoryPath, path.basename(relativePath)),
    );
  }

  Future<int> _objectLength(CacheObject object) async {
    final recordedLength = object.length;
    if (recordedLength != null && recordedLength > 0) {
      return recordedLength;
    }
    final cacheFile = _fileSystem.file(object.relativePath);
    if (!await cacheFile.exists()) {
      return 0;
    }
    return cacheFile.length();
  }

  Future<void> _repairMalformedMetadataFile() async {
    final metadataFile = _fileSystem.file(metadataFilePath);
    if (!await metadataFile.exists()) return;

    var shouldReset = await metadataFile.length() == 0;
    if (!shouldReset) {
      try {
        final decoded = jsonDecode(await metadataFile.readAsString());
        shouldReset = decoded is! List<dynamic>;
      } on FormatException {
        shouldReset = true;
      }
    }

    if (shouldReset) {
      await metadataFile.writeAsString('[]', flush: true);
    }
  }
}

class _AbsoluteCacheFileSystem implements FileSystem {
  static const LocalFileSystem _fileSystem = LocalFileSystem();

  final String directoryPath;

  const _AbsoluteCacheFileSystem(this.directoryPath);

  @override
  Future<file.File> createFile(String name) async {
    if (path.isAbsolute(name)) {
      return _fileSystem.file(name);
    }
    final directory = _fileSystem.directory(directoryPath);
    await directory.create(recursive: true);
    return directory.childFile(path.basename(name));
  }
}
