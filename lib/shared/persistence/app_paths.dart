import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  final Directory rootDirectory;
  final Directory settingsDirectory;
  final File settingsFile;
  final File trackedAnimeFile;
  final Directory networkDirectory;
  final Directory networkCookiesDirectory;
  final Directory networkDioCacheDirectory;
  final File cfSessionsFile;
  final File sourceDirectoryFile;
  final File sourceDirectoryFetchStateFile;
  final Directory cacheDirectory;
  final Directory stateDirectory;
  final File windowStateFile;
  final Directory imageCacheDirectory;
  final Directory imageCacheMetadataDirectory;
  final File imageCacheMetadataFile;
  final Directory logsDirectory;
  final Directory updatesDirectory;
  final File updateStateFile;
  final File updateManifestFile;

  const AppPaths._({
    required this.rootDirectory,
    required this.settingsDirectory,
    required this.settingsFile,
    required this.trackedAnimeFile,
    required this.networkDirectory,
    required this.networkCookiesDirectory,
    required this.networkDioCacheDirectory,
    required this.cfSessionsFile,
    required this.sourceDirectoryFile,
    required this.sourceDirectoryFetchStateFile,
    required this.cacheDirectory,
    required this.stateDirectory,
    required this.windowStateFile,
    required this.imageCacheDirectory,
    required this.imageCacheMetadataDirectory,
    required this.imageCacheMetadataFile,
    required this.logsDirectory,
    required this.updatesDirectory,
    required this.updateStateFile,
    required this.updateManifestFile,
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
    final stateDirectory = Directory(path.join(rootDirectory.path, 'state'));
    final imageCacheDirectory = Directory(
      path.join(cacheDirectory.path, 'images'),
    );
    final imageCacheMetadataDirectory = Directory(
      path.join(cacheDirectory.path, 'metadata'),
    );
    final logsDirectory = Directory(path.join(rootDirectory.path, 'logs'));
    final updatesDirectory = Directory(
      path.join(rootDirectory.path, 'updates'),
    );

    final paths = AppPaths._(
      rootDirectory: rootDirectory,
      settingsDirectory: settingsDirectory,
      settingsFile: File(
        path.join(settingsDirectory.path, 'app_settings.json'),
      ),
      trackedAnimeFile: File(
        path.join(settingsDirectory.path, 'tracked_anime.json'),
      ),
      networkDirectory: networkDirectory,
      networkCookiesDirectory: networkCookiesDirectory,
      networkDioCacheDirectory: networkDioCacheDirectory,
      cfSessionsFile: File(
        path.join(networkDirectory.path, 'cf_sessions.json'),
      ),
      sourceDirectoryFile: File(
        path.join(networkDirectory.path, 'source_directory.json'),
      ),
      sourceDirectoryFetchStateFile: File(
        path.join(networkDirectory.path, 'source_directory_fetch_state.json'),
      ),
      cacheDirectory: cacheDirectory,
      stateDirectory: stateDirectory,
      windowStateFile: File(
        path.join(stateDirectory.path, 'window_state.json'),
      ),
      imageCacheDirectory: imageCacheDirectory,
      imageCacheMetadataDirectory: imageCacheMetadataDirectory,
      imageCacheMetadataFile: File(
        path.join(imageCacheMetadataDirectory.path, 'image_cache.json'),
      ),
      logsDirectory: logsDirectory,
      updatesDirectory: updatesDirectory,
      updateStateFile: File(path.join(updatesDirectory.path, 'state.json')),
      updateManifestFile: File(
        path.join(updatesDirectory.path, 'manifest.json'),
      ),
    );

    await Future.wait([
      rootDirectory.create(recursive: true),
      settingsDirectory.create(recursive: true),
      networkDirectory.create(recursive: true),
      networkCookiesDirectory.create(recursive: true),
      networkDioCacheDirectory.create(recursive: true),
      cacheDirectory.create(recursive: true),
      stateDirectory.create(recursive: true),
      imageCacheDirectory.create(recursive: true),
      imageCacheMetadataDirectory.create(recursive: true),
      logsDirectory.create(recursive: true),
      updatesDirectory.create(recursive: true),
    ]);

    return paths;
  }
}
