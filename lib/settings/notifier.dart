import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';
import 'package:senpwai/settings/models.dart';
import 'package:senpwai/shared/net/download/download_config.dart';
import 'package:senpwai/shared/net/net_config.dart';
import 'package:senpwai/shared/persistence/app_image_cache.dart';
import 'package:senpwai/shared/persistence/app_persistence.dart';
import 'package:senpwai/shared/persistence/secure_token_store.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';
import 'package:senpwai/ui/shared/launch_at_startup_manager.dart';

class AppSettingsNotifier extends Notifier<AppSettings> {
  static final provider = NotifierProvider<AppSettingsNotifier, AppSettings>(
    AppSettingsNotifier.new,
  );

  @override
  AppSettings build() => AppPersistence.settings;

  AppSettings get currentState => state;

  Future<void> _commit(AppSettings next) async {
    state = next;
    await AppPersistence.settingsRepository.save(next);
    AppPersistence.settings = next;
    _applyRuntimeSettings(next);
  }

  void _applyRuntimeSettings(AppSettings settings) {
    DownloadConfig.getInstance().updateMaxBytesPerSecond(
      settings.downloads.maxDownloadBytesPerSecond.toDouble(),
    );
    NetConfig.getInstance().updateCacheMaxStale(
      settings.storage.httpCacheMaxAge,
    );
    AppImageCache.applyMaxSizeBytes(settings.storage.imageCacheMaxBytes);
  }

  Future<void> setBrightnessMode(BrightnessMode mode) {
    return _commit(
      state.copyWith(
        appearance: state.appearance.copyWith(brightnessMode: mode),
      ),
    );
  }

  Future<void> setThemePreset(SenpwaiThemePreset preset) {
    return _commit(
      state.copyWith(
        appearance: state.appearance.copyWith(themePreset: preset),
      ),
    );
  }

  Future<void> setDisplayFontFamily(String family) {
    return _commit(
      state.copyWith(
        appearance: state.appearance.copyWith(displayFontFamily: family),
      ),
    );
  }

  Future<void> setBodyFontFamily(String family) {
    return _commit(
      state.copyWith(
        appearance: state.appearance.copyWith(bodyFontFamily: family),
      ),
    );
  }

  Future<void> setCardViewMode(CardViewMode mode) {
    return _commit(
      state.copyWith(appearance: state.appearance.copyWith(cardViewMode: mode)),
    );
  }

  Future<void> setWindowAlwaysOnTop(bool alwaysOnTop) {
    return _commit(
      state.copyWith(window: state.window.copyWith(alwaysOnTop: alwaysOnTop)),
    );
  }

  Future<void> setWindowStartMaximized(bool startMaximized) {
    return _commit(
      state.copyWith(
        window: state.window.copyWith(
          startMaximized: startMaximized,
          startFullScreen: startMaximized ? false : null,
        ),
      ),
    );
  }

  Future<void> setWindowStartFullScreen(bool startFullScreen) {
    return _commit(
      state.copyWith(
        window: state.window.copyWith(
          startFullScreen: startFullScreen,
          startMaximized: startFullScreen ? false : null,
        ),
      ),
    );
  }

  Future<void> setLaunchAtStartup(bool launchAtStartup) async {
    await LaunchAtStartupManager.getInstance().setEnabled(launchAtStartup);
    await _commit(
      state.copyWith(
        window: state.window.copyWith(launchAtStartup: launchAtStartup),
      ),
    );
  }

  Future<void> setTitleLanguage(TitleLanguagePreference language) {
    return _commit(
      state.copyWith(content: state.content.copyWith(titleLanguage: language)),
    );
  }

  Future<void> setShowAdultContent(bool show) {
    return _commit(
      state.copyWith(content: state.content.copyWith(showAdultContent: show)),
    );
  }

  Future<void> setDefaultResolution(Resolution resolution) {
    return _commit(
      state.copyWith(
        content: state.content.copyWith(defaultResolution: resolution),
      ),
    );
  }

  Future<void> setDefaultAudioLanguage(Language language) {
    return _commit(
      state.copyWith(
        content: state.content.copyWith(defaultAudioLanguage: language),
      ),
    );
  }

  Future<void> setDefaultDownloadRoot(String? root) {
    final roots = root == null ? const <String>[] : [root];
    return setDownloadRootDirectories(roots);
  }

  Future<void> setDownloadRootDirectories(List<String> roots) {
    final normalizedRoots = _uniqueNonEmptyStrings(roots);
    return _commit(
      state.copyWith(
        downloads: state.downloads.copyWith(
          defaultRootDirectory: normalizedRoots.firstOrNull,
          rootDirectories: normalizedRoots,
          clearDefaultRootDirectory: normalizedRoots.isEmpty,
        ),
      ),
    );
  }

  Future<void> addDownloadRootDirectory(String root) {
    final normalized = root.trim();
    if (normalized.isEmpty) return Future.value();
    return setDownloadRootDirectories([
      ...state.downloads.effectiveRootDirectories,
      normalized,
    ]);
  }

  Future<void> removeDownloadRootDirectory(String root) {
    return setDownloadRootDirectories([
      for (final existing in state.downloads.effectiveRootDirectories)
        if (existing != root) existing,
    ]);
  }

  Future<void> upsertCustomAnimeFolder({
    required String animeTitle,
    required String folder,
  }) {
    final normalizedTitle = animeTitle.trim();
    final normalizedFolder = folder.trim();
    if (normalizedTitle.isEmpty || normalizedFolder.isEmpty) {
      return Future.value();
    }
    final nextFolders = [
      for (final existing in state.downloads.customAnimeFolders)
        if (_folderTitleKey(existing.animeTitle) !=
            _folderTitleKey(normalizedTitle))
          existing,
      CustomAnimeFolder(animeTitle: normalizedTitle, folder: normalizedFolder),
    ];
    return _commit(
      state.copyWith(
        downloads: state.downloads.copyWith(customAnimeFolders: nextFolders),
      ),
    );
  }

  Future<void> setHttpMaxDownloadBytesPerSecond(int bytes) {
    return _commit(
      state.copyWith(
        downloads: state.downloads.copyWith(
          maxDownloadBytesPerSecond: bytes < 0 ? 0 : bytes,
        ),
      ),
    );
  }

  Future<void> setSkipFillers(bool skip) {
    return _commit(
      state.copyWith(downloads: state.downloads.copyWith(skipFillers: skip)),
    );
  }

  Future<void> setEnabledSources(Set<AnimeSource> sources) {
    if (sources.isEmpty) return Future.value();
    return _commit(
      state.copyWith(sources: state.sources.copyWith(enabledSources: sources)),
    );
  }

  Future<void> setSourcePriority(List<AnimeSource> priority) {
    return _commit(
      state.copyWith(sources: state.sources.copyWith(priority: priority)),
    );
  }

  Future<void> setNyaaDefaultFilters(NyaaManualSearchFilters filters) {
    return _commit(
      state.copyWith(
        sources: state.sources.copyWith(nyaaDefaultFilters: filters),
      ),
    );
  }

  Future<void> setTorrentMaxDownloadBytesPerSecond(int bytes) {
    return _commit(
      state.copyWith(
        torrent: state.torrent.copyWith(
          maxDownloadBytesPerSecond: bytes < 0 ? 0 : bytes,
        ),
      ),
    );
  }

  Future<void> setTorrentMaxUploadBytesPerSecond(int bytes) {
    return _commit(
      state.copyWith(
        torrent: state.torrent.copyWith(
          maxUploadBytesPerSecond: bytes < 0 ? 0 : bytes,
        ),
      ),
    );
  }

  Future<void> setTorrentLimits({
    int? maxActiveDownloads,
    int? maxActiveSeeds,
    int? maxConnections,
    int? seedRatioLimit,
    int? seedTimeLimitMinutes,
    int? torrentPort,
  }) {
    return _commit(
      state.copyWith(
        torrent: state.torrent.copyWith(
          maxActiveDownloads: maxActiveDownloads == null
              ? null
              : maxActiveDownloads < 1
              ? 1
              : maxActiveDownloads,
          maxActiveSeeds: maxActiveSeeds == null
              ? null
              : maxActiveSeeds < 1
              ? 1
              : maxActiveSeeds,
          maxConnections: maxConnections == null
              ? null
              : maxConnections < 1
              ? 1
              : maxConnections,
          seedRatioLimit: seedRatioLimit == null
              ? null
              : seedRatioLimit < 0
              ? 0
              : seedRatioLimit,
          seedTimeLimitMinutes: seedTimeLimitMinutes == null
              ? null
              : seedTimeLimitMinutes < 0
              ? 0
              : seedTimeLimitMinutes,
          torrentPort: torrentPort?.clamp(0, 65535).toInt(),
        ),
      ),
    );
  }

  Future<void> setTorrentAdvanced({
    TorrentEncryptionMode? encryptionMode,
    bool? anonymousMode,
    bool? enableIncomingTcp,
    bool? enableIncomingUtp,
    bool? enableOutgoingTcp,
    bool? enableOutgoingUtp,
  }) {
    return _commit(
      state.copyWith(
        torrent: state.torrent.copyWith(
          encryptionMode: encryptionMode,
          anonymousMode: anonymousMode,
          enableIncomingTcp: enableIncomingTcp,
          enableIncomingUtp: enableIncomingUtp,
          enableOutgoingTcp: enableOutgoingTcp,
          enableOutgoingUtp: enableOutgoingUtp,
        ),
      ),
    );
  }

  Future<void> setTorrentProxy({
    TorrentProxyMode? proxyMode,
    String? proxyHost,
    int? proxyPort,
    String? proxyUsername,
    String? proxyPassword,
  }) {
    final nextProxy = state.torrent.copyWith(
      proxyMode: proxyMode,
      proxyHost: proxyHost,
      proxyPort: proxyPort?.clamp(0, 65535).toInt(),
      proxyUsername: proxyUsername,
      proxyPassword: proxyPassword,
    );
    final persistProxy = AppPersistence.secureTokenStore
        .writeTorrentProxyConfiguration(
          SecureTorrentProxyConfiguration(
            mode: nextProxy.proxyMode.name,
            host: nextProxy.proxyHost,
            port: nextProxy.proxyPort,
            username: nextProxy.proxyUsername,
            password: nextProxy.proxyPassword,
          ),
        );
    return persistProxy.then(
      (_) => _commit(state.copyWith(torrent: nextProxy)),
    );
  }

  Future<void> setTorrentDiscovery({
    bool? enableDht,
    bool? enableLsd,
    bool? enableUpnp,
    bool? enableNatPmp,
  }) {
    return _commit(
      state.copyWith(
        torrent: state.torrent.copyWith(
          enableDht: enableDht,
          enableLsd: enableLsd,
          enableUpnp: enableUpnp,
          enableNatPmp: enableNatPmp,
        ),
      ),
    );
  }

  Future<void> setTrackerCheckIntervalHours(int hours) {
    return _commit(
      state.copyWith(
        anilist: state.anilist.copyWith(
          trackerCheckIntervalHours: hours < 0 ? 0 : hours,
        ),
      ),
    );
  }

  Future<void> setImageCacheMaxBytes(int bytes) {
    return _commit(
      state.copyWith(
        storage: state.storage.copyWith(
          imageCacheMaxBytes: bytes < 0 ? 0 : bytes,
        ),
      ),
    );
  }

  Future<bool> setHttpCacheMaxAge(Duration duration) async {
    final normalized = StoragePreferences.normalizeHttpCacheMaxAge(duration);
    await _commit(
      state.copyWith(
        storage: state.storage.copyWith(
          httpCacheMaxAgeSeconds: normalized.inSeconds,
        ),
      ),
    );
    return normalized != duration;
  }

  Future<void> setNotificationsEnabled(bool enabled) {
    return _commit(
      state.copyWith(
        notifications: state.notifications.copyWith(
          enabled: enabled,
          permissionDenied: enabled
              ? state.notifications.permissionDenied
              : false,
        ),
      ),
    );
  }

  Future<void> setNotificationPermissionDenied(bool denied) {
    return _commit(
      state.copyWith(
        notifications: state.notifications.copyWith(
          enabled: denied ? false : state.notifications.enabled,
          permissionDenied: denied,
        ),
      ),
    );
  }

  Future<void> setDownloadNotificationStyle(DownloadNotificationStyle style) {
    return _commit(
      state.copyWith(
        notifications: state.notifications.copyWith(downloadStyle: style),
      ),
    );
  }
}

List<String> _uniqueNonEmptyStrings(List<String> values) {
  final normalized = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && !normalized.contains(trimmed)) {
      normalized.add(trimmed);
    }
  }
  return normalized;
}

String _folderTitleKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[\s._-]+'), '');
