import 'dart:io';

import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/net/download/download_config.dart';
import 'package:senpwai/shared/net/browser_transport/browser_transport.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/net/net_config.dart';
import 'package:senpwai/shared/persistence/app_image_cache.dart';
import 'package:senpwai/shared/persistence/app_paths.dart';
import 'package:senpwai/shared/persistence/secure_token_store.dart';
import 'package:senpwai/shared/source_directory/source_directory.dart';
import 'package:senpwai/shared/persistence/window_state_repository.dart';
import 'package:senpwai/tracking/models.dart';
import 'package:senpwai/tracking/repository.dart';

class AppPersistence {
  static AppPaths? _paths;
  static AppSettingsRepository? _settingsRepository;
  static AppSettings? _settings;
  static TrackingRepository? _trackingRepository;
  static List<TrackedAnime>? _trackedAnime;
  static SecureTokenStore? _secureTokenStore;
  static WindowStateRepository? _windowStateRepository;

  AppPersistence._();

  static AppPaths get paths {
    final resolved = _paths;
    if (resolved == null) {
      throw StateError('AppPersistence.initialize must be called first.');
    }
    return resolved;
  }

  static SecureTokenStore get secureTokenStore {
    final resolved = _secureTokenStore;
    if (resolved == null) {
      throw StateError('AppPersistence.initialize must be called first.');
    }
    return resolved;
  }

  static WindowStateRepository get windowStateRepository {
    final resolved = _windowStateRepository;
    if (resolved == null) {
      throw StateError('AppPersistence.initialize must be called first.');
    }
    return resolved;
  }

  static AppSettingsRepository get settingsRepository {
    final resolved = _settingsRepository;
    if (resolved == null) {
      throw StateError('AppPersistence.initialize must be called first.');
    }
    return resolved;
  }

  static TrackingRepository get trackingRepository {
    final resolved = _trackingRepository;
    if (resolved == null) {
      throw StateError('AppPersistence.initialize must be called first.');
    }
    return resolved;
  }

  static List<TrackedAnime> get trackedAnime {
    final resolved = _trackedAnime;
    if (resolved == null) {
      throw StateError('AppPersistence.initialize must be called first.');
    }
    return resolved;
  }

  static set trackedAnime(List<TrackedAnime> value) {
    if (_trackedAnime == null) {
      throw StateError('AppPersistence.initialize must be called first.');
    }
    _trackedAnime = value;
  }

  static AppSettings get settings {
    final resolved = _settings;
    if (resolved == null) {
      throw StateError('AppPersistence.initialize must be called first.');
    }
    return resolved;
  }

  static set settings(AppSettings value) {
    if (_settings == null) {
      throw StateError('AppPersistence.initialize must be called first.');
    }
    _settings = value;
  }

  static Future<void> initialize({Directory? rootDirectory}) async {
    if (_paths != null) return;

    final initializedPaths = rootDirectory == null
        ? await AppPaths.initialize()
        : await AppPaths.fromRootDirectory(rootDirectory);
    final settingsRepository = AppSettingsRepository(
      file: initializedPaths.settingsFile,
    );
    final loadedSettings = await settingsRepository.load();
    final windowStateRepository = WindowStateRepository(
      file: initializedPaths.windowStateFile,
    );
    final trackingRepository = TrackingRepository(
      file: initializedPaths.trackedAnimeFile,
    );
    final loadedTrackedAnime = await trackingRepository.load();
    final tokenStore = SecureTokenStore(
      settingsRepository: settingsRepository,
      readSettings: () => _settings ?? loadedSettings,
      writeSettings: (settings) => _settings = settings,
    );
    final proxyConfiguration = await tokenStore.readTorrentProxyConfiguration();
    final settings =
        proxyConfiguration == null ||
            loadedSettings.torrent.proxyMode == TorrentProxyMode.none
        ? loadedSettings
        : loadedSettings.copyWith(
            torrent: loadedSettings.torrent.copyWith(
              proxyUsername: proxyConfiguration.username,
              proxyPassword: proxyConfiguration.password,
            ),
          );

    _paths = initializedPaths;
    _settingsRepository = settingsRepository;
    _settings = settings;
    _trackingRepository = trackingRepository;
    _trackedAnime = loadedTrackedAnime;
    _secureTokenStore = tokenStore;
    _windowStateRepository = windowStateRepository;

    DownloadConfig.getInstance().updateMaxBytesPerSecond(
      settings.downloads.maxDownloadBytesPerSecond.toDouble(),
    );
    NetConfig.initialize(paths: initializedPaths);
    NetConfig.getInstance().updateCacheMaxStale(
      settings.storage.httpCacheMaxAge,
    );
    AppImageCache.initialize(
      initializedPaths,
      maxSizeBytes: settings.storage.imageCacheMaxBytes,
    );
    await GlobalDio.initialize(paths: initializedPaths);
    BrowserTransportService.instance.updateIdleTimeout(
      settings.sources.browserTransportIdleTimeout,
    );
    await SourceDirectory.initialize(paths: initializedPaths);
    _updateSourceDirectoryConcurrency(SourceDirectory.instance);
    SourceDirectory.changes.listen(_updateSourceDirectoryConcurrency);
  }

  static void _updateSourceDirectoryConcurrency(SourceDirectory directory) {
    GlobalDio.updateHostConcurrencyLimits({
      for (final host in directory.nyaa.allowedHosts)
        host: directory.nyaa.maxConcurrentRequests ?? 5,
      for (final host in directory.animePahe.allowedHosts)
        host: directory.animePahe.maxConcurrentRequests ?? 4,
      for (final host in directory.kwik.allowedHosts)
        host: directory.kwik.maxConcurrentRequests ?? 1,
    });
    GlobalDio.updateBrowserOrigins({
      ..._browserOrigins(directory.animePahe),
      ..._browserOrigins(directory.kwik),
    });
  }

  static Map<String, Uri> _browserOrigins(SourceEndpoint endpoint) {
    final baseUri = Uri.parse(endpoint.baseUrl);
    return {
      for (final host in endpoint.allowedHosts)
        host: host == baseUri.host ? baseUri : Uri.https(host, '/'),
    };
  }

  static Future<void> clearNetworkSession() async {
    await Future.wait([
      GlobalDio.cookieJar.deleteAll(),
      BrowserTransportService.instance.clearSessions(),
    ]);
  }

  static Future<void> clearHttpCache() async {
    await NetConfig.getInstance().cacheStore?.clean();
  }

  static Future<void> clearImageCache() async {
    await AppImageCache.manager.emptyCache();
  }

  static Future<void> clearAppCacheAndSessions() async {
    await Future.wait([
      clearImageCache(),
      clearHttpCache(),
      clearNetworkSession(),
    ]);
  }
}
