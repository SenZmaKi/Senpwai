import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';
import 'package:senpwai/settings/models.dart';
import 'package:senpwai/shared/net/download/download_config.dart';
import 'package:senpwai/shared/net/net_config.dart';
import 'package:senpwai/shared/persistence/app_image_cache.dart';
import 'package:senpwai/shared/persistence/app_persistence.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

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
    return _commit(
      state.copyWith(
        downloads: state.downloads.copyWith(
          defaultRootDirectory: root,
          clearDefaultRootDirectory: root == null,
        ),
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

  Future<void> setSyncWatchingToTrackedAnime(bool sync) {
    return _commit(
      state.copyWith(
        anilist: state.anilist.copyWith(syncWatchingToTrackedAnime: sync),
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
