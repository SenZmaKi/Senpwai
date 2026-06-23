import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  final Directory rootDirectory;
  final Directory settingsDirectory;
  final Directory networkDirectory;
  final Directory networkCookiesDirectory;
  final Directory networkDioCacheDirectory;
  final File cfSessionsFile;
  final Directory cacheDirectory;
  final Directory imageCacheDirectory;
  final Directory imageCacheMetadataDirectory;
  final File imageCacheMetadataFile;
  final Directory logsDirectory;

  const AppPaths._({
    required this.rootDirectory,
    required this.settingsDirectory,
    required this.networkDirectory,
    required this.networkCookiesDirectory,
    required this.networkDioCacheDirectory,
    required this.cfSessionsFile,
    required this.cacheDirectory,
    required this.imageCacheDirectory,
    required this.imageCacheMetadataDirectory,
    required this.imageCacheMetadataFile,
    required this.logsDirectory,
  });

  static Future<AppPaths> initialize() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final rootDirectory = Directory(
      path.join(supportDirectory.path, 'SenpwaiData'),
    );
    return fromRootDirectory(rootDirectory);
  }

  static Future<AppPaths> fromRootDirectory(Directory rootDirectory) async {
    final settingsDirectory = Directory(
      path.join(rootDirectory.path, 'settings'),
    );
    final networkDirectory = Directory(
      path.join(rootDirectory.path, 'network'),
    );
    final networkCookiesDirectory = Directory(
      path.join(networkDirectory.path, 'cookies'),
    );
    final networkDioCacheDirectory = Directory(
      path.join(networkDirectory.path, 'dio_cache'),
    );
    final cacheDirectory = Directory(path.join(rootDirectory.path, 'cache'));
    final imageCacheDirectory = Directory(
      path.join(cacheDirectory.path, 'images'),
    );
    final imageCacheMetadataDirectory = Directory(
      path.join(cacheDirectory.path, 'metadata'),
    );
    final logsDirectory = Directory(path.join(rootDirectory.path, 'logs'));

    final paths = AppPaths._(
      rootDirectory: rootDirectory,
      settingsDirectory: settingsDirectory,
      networkDirectory: networkDirectory,
      networkCookiesDirectory: networkCookiesDirectory,
      networkDioCacheDirectory: networkDioCacheDirectory,
      cfSessionsFile: File(
        path.join(networkDirectory.path, 'cf_sessions.json'),
      ),
      cacheDirectory: cacheDirectory,
      imageCacheDirectory: imageCacheDirectory,
      imageCacheMetadataDirectory: imageCacheMetadataDirectory,
      imageCacheMetadataFile: File(
        path.join(imageCacheMetadataDirectory.path, 'image_cache.json'),
      ),
      logsDirectory: logsDirectory,
    );

    await Future.wait([
      rootDirectory.create(recursive: true),
      settingsDirectory.create(recursive: true),
      networkDirectory.create(recursive: true),
      networkCookiesDirectory.create(recursive: true),
      networkDioCacheDirectory.create(recursive: true),
      cacheDirectory.create(recursive: true),
      imageCacheDirectory.create(recursive: true),
      imageCacheMetadataDirectory.create(recursive: true),
      logsDirectory.create(recursive: true),
    ]);

    return paths;
  }
}
