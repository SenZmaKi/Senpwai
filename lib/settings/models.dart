import 'package:flutter/material.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';
import 'package:senpwai/sources/shared/matcher/nyaa.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

enum TitleLanguagePreference {
  romaji,
  english,
  native;

  String get label => switch (this) {
    TitleLanguagePreference.romaji => 'Romaji',
    TitleLanguagePreference.english => 'English',
    TitleLanguagePreference.native => 'Native',
  };
}

enum DownloadNotificationStyle {
  batchSummary,
  eachDownload,
  completionOnly;

  String get label => switch (this) {
    DownloadNotificationStyle.batchSummary => 'Batch summary',
    DownloadNotificationStyle.eachDownload => 'Each download',
    DownloadNotificationStyle.completionOnly => 'Completion only',
  };
}

extension AnilistTitleLanguageDisplay on TitleLanguagePreference {
  String displayTitle({
    required String? romaji,
    required String? english,
    required String? native,
  }) {
    final candidates = switch (this) {
      TitleLanguagePreference.romaji => [romaji, english, native],
      TitleLanguagePreference.english => [english, romaji, native],
      TitleLanguagePreference.native => [native, romaji, english],
    };
    for (final candidate in candidates) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return '?';
  }
}

@immutable
class AppSettings {
  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final AppearancePreferences appearance;
  final ContentPreferences content;
  final DownloadPreferences downloads;
  final SourcePreferences sources;
  final TorrentPreferences torrent;
  final AnilistPreferences anilist;
  final StoragePreferences storage;
  final NotificationPreferences notifications;

  const AppSettings({
    this.schemaVersion = currentSchemaVersion,
    this.appearance = const AppearancePreferences(),
    this.content = const ContentPreferences(),
    this.downloads = const DownloadPreferences(),
    this.sources = const SourcePreferences(),
    this.torrent = const TorrentPreferences(),
    this.anilist = const AnilistPreferences(),
    this.storage = const StoragePreferences(),
    this.notifications = const NotificationPreferences(),
  });

  factory AppSettings.defaults() => const AppSettings();

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    schemaVersion: _intValue(json['schemaVersion'], currentSchemaVersion),
    appearance: AppearancePreferences.fromJson(_mapValue(json['appearance'])),
    content: ContentPreferences.fromJson(_mapValue(json['content'])),
    downloads: DownloadPreferences.fromJson(_mapValue(json['downloads'])),
    sources: SourcePreferences.fromJson(_mapValue(json['sources'])),
    torrent: TorrentPreferences.fromJson(_mapValue(json['torrent'])),
    anilist: AnilistPreferences.fromJson(_mapValue(json['anilist'])),
    storage: StoragePreferences.fromJson(_mapValue(json['storage'])),
    notifications: NotificationPreferences.fromJson(
      _mapValue(json['notifications']),
    ),
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'appearance': appearance.toJson(),
    'content': content.toJson(),
    'downloads': downloads.toJson(),
    'sources': sources.toJson(),
    'torrent': torrent.toJson(),
    'anilist': anilist.toJson(),
    'storage': storage.toJson(),
    'notifications': notifications.toJson(),
  };

  String displayTitle(AnilistTitle title) => content.titleLanguage.displayTitle(
    romaji: title.romaji,
    english: title.english,
    native: title.native,
  );

  AppSettings copyWith({
    AppearancePreferences? appearance,
    ContentPreferences? content,
    DownloadPreferences? downloads,
    SourcePreferences? sources,
    TorrentPreferences? torrent,
    AnilistPreferences? anilist,
    StoragePreferences? storage,
    NotificationPreferences? notifications,
  }) {
    return AppSettings(
      schemaVersion: schemaVersion,
      appearance: appearance ?? this.appearance,
      content: content ?? this.content,
      downloads: downloads ?? this.downloads,
      sources: sources ?? this.sources,
      torrent: torrent ?? this.torrent,
      anilist: anilist ?? this.anilist,
      storage: storage ?? this.storage,
      notifications: notifications ?? this.notifications,
    );
  }
}

@immutable
class AppearancePreferences {
  final BrightnessMode brightnessMode;
  final SenpwaiThemePreset themePreset;
  final String displayFontFamily;
  final String bodyFontFamily;

  const AppearancePreferences({
    this.brightnessMode = BrightnessMode.system,
    this.themePreset = SenpwaiThemePreset.defaultTheme,
    this.displayFontFamily = 'Orbitron',
    this.bodyFontFamily = 'Exo 2',
  });

  factory AppearancePreferences.fromJson(Map<String, dynamic> json) =>
      AppearancePreferences(
        brightnessMode: _enumValue(
          BrightnessMode.values,
          json['brightnessMode'],
          BrightnessMode.system,
        ),
        themePreset: _enumValue(
          SenpwaiThemePreset.values,
          json['themePreset'],
          SenpwaiThemePreset.defaultTheme,
        ),
        displayFontFamily: _stringValue(json['displayFontFamily'], 'Orbitron'),
        bodyFontFamily: _stringValue(json['bodyFontFamily'], 'Exo 2'),
      );

  Map<String, dynamic> toJson() => {
    'brightnessMode': brightnessMode.name,
    'themePreset': themePreset.name,
    'displayFontFamily': displayFontFamily,
    'bodyFontFamily': bodyFontFamily,
  };

  ThemeConfig toThemeConfig() {
    final presetTheme = themePreset.toTheme();
    return ThemeConfig(
      brightnessMode: brightnessMode,
      theme: presetTheme.copyWith(
        typography: presetTheme.typography.copyWith(
          displayFamily: displayFontFamily,
          bodyFamily: bodyFontFamily,
        ),
      ),
      activePreset: themePreset,
    );
  }

  AppearancePreferences copyWith({
    BrightnessMode? brightnessMode,
    SenpwaiThemePreset? themePreset,
    String? displayFontFamily,
    String? bodyFontFamily,
  }) {
    final nextPreset = themePreset ?? this.themePreset;
    final presetChanged =
        themePreset != null && themePreset != this.themePreset;
    final presetTheme = nextPreset.toTheme();
    return AppearancePreferences(
      brightnessMode: brightnessMode ?? this.brightnessMode,
      themePreset: nextPreset,
      displayFontFamily:
          displayFontFamily ??
          (presetChanged
              ? presetTheme.typography.displayFamily
              : this.displayFontFamily),
      bodyFontFamily:
          bodyFontFamily ??
          (presetChanged
              ? presetTheme.typography.bodyFamily
              : this.bodyFontFamily),
    );
  }
}

@immutable
class ContentPreferences {
  final TitleLanguagePreference titleLanguage;
  final bool showAdultContent;
  final Resolution defaultResolution;
  final Language defaultAudioLanguage;

  const ContentPreferences({
    this.titleLanguage = TitleLanguagePreference.romaji,
    this.showAdultContent = false,
    this.defaultResolution = Resolution.res1080p,
    this.defaultAudioLanguage = Language.japanese,
  });

  factory ContentPreferences.fromJson(Map<String, dynamic> json) =>
      ContentPreferences(
        titleLanguage: _enumValue(
          TitleLanguagePreference.values,
          json['titleLanguage'],
          TitleLanguagePreference.romaji,
        ),
        showAdultContent: _boolValue(json['showAdultContent'], false),
        defaultResolution: _enumValue(
          Resolution.values,
          json['defaultResolution'],
          Resolution.res1080p,
        ),
        defaultAudioLanguage: _enumValue(
          Language.values,
          json['defaultAudioLanguage'],
          Language.japanese,
        ),
      );

  Map<String, dynamic> toJson() => {
    'titleLanguage': titleLanguage.name,
    'showAdultContent': showAdultContent,
    'defaultResolution': defaultResolution.name,
    'defaultAudioLanguage': defaultAudioLanguage.name,
  };

  ContentPreferences copyWith({
    TitleLanguagePreference? titleLanguage,
    bool? showAdultContent,
    Resolution? defaultResolution,
    Language? defaultAudioLanguage,
  }) {
    return ContentPreferences(
      titleLanguage: titleLanguage ?? this.titleLanguage,
      showAdultContent: showAdultContent ?? this.showAdultContent,
      defaultResolution: defaultResolution ?? this.defaultResolution,
      defaultAudioLanguage: defaultAudioLanguage ?? this.defaultAudioLanguage,
    );
  }
}

@immutable
class DownloadPreferences {
  final String? defaultRootDirectory;
  final int maxDownloadBytesPerSecond;

  const DownloadPreferences({
    this.defaultRootDirectory,
    this.maxDownloadBytesPerSecond = 0,
  });

  factory DownloadPreferences.fromJson(Map<String, dynamic> json) =>
      DownloadPreferences(
        defaultRootDirectory: _nullableStringValue(
          json['defaultRootDirectory'],
        ),
        maxDownloadBytesPerSecond: _nonNegativeIntValue(
          json['maxDownloadBytesPerSecond'],
          0,
        ),
      );

  Map<String, dynamic> toJson() => {
    'defaultRootDirectory': defaultRootDirectory,
    'maxDownloadBytesPerSecond': maxDownloadBytesPerSecond,
  };

  DownloadPreferences copyWith({
    String? defaultRootDirectory,
    int? maxDownloadBytesPerSecond,
    bool clearDefaultRootDirectory = false,
  }) {
    return DownloadPreferences(
      defaultRootDirectory: clearDefaultRootDirectory
          ? null
          : (defaultRootDirectory ?? this.defaultRootDirectory),
      maxDownloadBytesPerSecond:
          maxDownloadBytesPerSecond ?? this.maxDownloadBytesPerSecond,
    );
  }
}

@immutable
class SourcePreferences {
  static const defaultPriority = [
    AnimeSource.animepahe,
    AnimeSource.tokyoinsider,
    AnimeSource.nyaa,
  ];

  final Set<AnimeSource> enabledSources;
  final List<AnimeSource> priority;
  final NyaaManualSearchFilters nyaaDefaultFilters;

  const SourcePreferences({
    this.enabledSources = const {
      AnimeSource.animepahe,
      AnimeSource.tokyoinsider,
      AnimeSource.nyaa,
    },
    this.priority = defaultPriority,
    this.nyaaDefaultFilters = const NyaaManualSearchFilters(),
  });

  factory SourcePreferences.fromJson(Map<String, dynamic> json) {
    final enabled = _enumSet(
      AnimeSource.values,
      json['enabledSources'],
      AnimeSource.values.toSet(),
    );
    final priority = _normalizedSourcePriority(
      _enumList(AnimeSource.values, json['priority'], defaultPriority),
    );
    return SourcePreferences(
      enabledSources: enabled.isEmpty ? AnimeSource.values.toSet() : enabled,
      priority: priority,
      nyaaDefaultFilters: nyaaFiltersFromJson(
        _mapValue(json['nyaaDefaultFilters']),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabledSources': enabledSources.map((source) => source.name).toList(),
    'priority': priority.map((source) => source.name).toList(),
    'nyaaDefaultFilters': nyaaFiltersToJson(nyaaDefaultFilters),
  };

  AnimeSource? get preferredEnabledSource {
    for (final source in priority) {
      if (enabledSources.contains(source)) return source;
    }
    return null;
  }

  SourcePreferences copyWith({
    Set<AnimeSource>? enabledSources,
    List<AnimeSource>? priority,
    NyaaManualSearchFilters? nyaaDefaultFilters,
  }) {
    final nextEnabled = enabledSources ?? this.enabledSources;
    return SourcePreferences(
      enabledSources: nextEnabled.isEmpty ? this.enabledSources : nextEnabled,
      priority: priority == null
          ? this.priority
          : _normalizedSourcePriority(priority),
      nyaaDefaultFilters: nyaaDefaultFilters ?? this.nyaaDefaultFilters,
    );
  }
}

@immutable
class TorrentPreferences {
  final int maxDownloadBytesPerSecond;
  final int maxUploadBytesPerSecond;
  final bool enableDht;
  final bool enableLsd;
  final bool enableUpnp;
  final bool enableNatPmp;

  const TorrentPreferences({
    this.maxDownloadBytesPerSecond = 0,
    this.maxUploadBytesPerSecond = 0,
    this.enableDht = true,
    this.enableLsd = true,
    this.enableUpnp = true,
    this.enableNatPmp = true,
  });

  factory TorrentPreferences.fromJson(Map<String, dynamic> json) =>
      TorrentPreferences(
        maxDownloadBytesPerSecond: _nonNegativeIntValue(
          json['maxDownloadBytesPerSecond'],
          0,
        ),
        maxUploadBytesPerSecond: _nonNegativeIntValue(
          json['maxUploadBytesPerSecond'],
          0,
        ),
        enableDht: _boolValue(json['enableDht'], true),
        enableLsd: _boolValue(json['enableLsd'], true),
        enableUpnp: _boolValue(json['enableUpnp'], true),
        enableNatPmp: _boolValue(json['enableNatPmp'], true),
      );

  Map<String, dynamic> toJson() => {
    'maxDownloadBytesPerSecond': maxDownloadBytesPerSecond,
    'maxUploadBytesPerSecond': maxUploadBytesPerSecond,
    'enableDht': enableDht,
    'enableLsd': enableLsd,
    'enableUpnp': enableUpnp,
    'enableNatPmp': enableNatPmp,
  };

  TorrentPreferences copyWith({
    int? maxDownloadBytesPerSecond,
    int? maxUploadBytesPerSecond,
    bool? enableDht,
    bool? enableLsd,
    bool? enableUpnp,
    bool? enableNatPmp,
  }) {
    return TorrentPreferences(
      maxDownloadBytesPerSecond:
          maxDownloadBytesPerSecond ?? this.maxDownloadBytesPerSecond,
      maxUploadBytesPerSecond:
          maxUploadBytesPerSecond ?? this.maxUploadBytesPerSecond,
      enableDht: enableDht ?? this.enableDht,
      enableLsd: enableLsd ?? this.enableLsd,
      enableUpnp: enableUpnp ?? this.enableUpnp,
      enableNatPmp: enableNatPmp ?? this.enableNatPmp,
    );
  }
}

@immutable
class AnilistPreferences {
  final bool syncWatchingToTrackedAnime;

  const AnilistPreferences({this.syncWatchingToTrackedAnime = false});

  factory AnilistPreferences.fromJson(Map<String, dynamic> json) =>
      AnilistPreferences(
        syncWatchingToTrackedAnime: _boolValue(
          json['syncWatchingToTrackedAnime'],
          false,
        ),
      );

  Map<String, dynamic> toJson() => {
    'syncWatchingToTrackedAnime': syncWatchingToTrackedAnime,
  };

  AnilistPreferences copyWith({bool? syncWatchingToTrackedAnime}) =>
      AnilistPreferences(
        syncWatchingToTrackedAnime:
            syncWatchingToTrackedAnime ?? this.syncWatchingToTrackedAnime,
      );
}

@immutable
class StoragePreferences {
  static const defaultImageCacheMaxBytes = 50 * 1024 * 1024;
  static const defaultHttpCacheMaxAgeSeconds = 60 * 60;

  final int imageCacheMaxBytes;
  final int httpCacheMaxAgeSeconds;

  const StoragePreferences({
    this.imageCacheMaxBytes = defaultImageCacheMaxBytes,
    this.httpCacheMaxAgeSeconds = defaultHttpCacheMaxAgeSeconds,
  });

  factory StoragePreferences.fromJson(Map<String, dynamic> json) =>
      StoragePreferences(
        imageCacheMaxBytes: _nonNegativeIntValue(
          json['imageCacheMaxBytes'],
          defaultImageCacheMaxBytes,
        ),
        httpCacheMaxAgeSeconds: normalizeHttpCacheMaxAgeSeconds(
          _intValue(
            json['httpCacheMaxAgeSeconds'],
            defaultHttpCacheMaxAgeSeconds,
          ),
        ),
      );

  Map<String, dynamic> toJson() => {
    'imageCacheMaxBytes': imageCacheMaxBytes,
    'httpCacheMaxAgeSeconds': httpCacheMaxAgeSeconds,
  };

  Duration get httpCacheMaxAge => Duration(seconds: httpCacheMaxAgeSeconds);

  static int normalizeHttpCacheMaxAgeSeconds(int seconds) =>
      seconds <= 0 ? defaultHttpCacheMaxAgeSeconds : seconds;

  static Duration normalizeHttpCacheMaxAge(Duration duration) =>
      Duration(seconds: normalizeHttpCacheMaxAgeSeconds(duration.inSeconds));

  StoragePreferences copyWith({
    int? imageCacheMaxBytes,
    int? httpCacheMaxAgeSeconds,
  }) {
    return StoragePreferences(
      imageCacheMaxBytes: imageCacheMaxBytes ?? this.imageCacheMaxBytes,
      httpCacheMaxAgeSeconds: httpCacheMaxAgeSeconds == null
          ? this.httpCacheMaxAgeSeconds
          : normalizeHttpCacheMaxAgeSeconds(httpCacheMaxAgeSeconds),
    );
  }
}

@immutable
class NotificationPreferences {
  final bool enabled;
  final bool permissionDenied;
  final DownloadNotificationStyle downloadStyle;

  const NotificationPreferences({
    this.enabled = true,
    this.permissionDenied = false,
    this.downloadStyle = DownloadNotificationStyle.batchSummary,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        enabled: _boolValue(json['enabled'], true),
        permissionDenied: _boolValue(json['permissionDenied'], false),
        downloadStyle: _enumValue(
          DownloadNotificationStyle.values,
          json['downloadStyle'],
          DownloadNotificationStyle.batchSummary,
        ),
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'permissionDenied': permissionDenied,
    'downloadStyle': downloadStyle.name,
  };

  NotificationPreferences copyWith({
    bool? enabled,
    bool? permissionDenied,
    DownloadNotificationStyle? downloadStyle,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      downloadStyle: downloadStyle ?? this.downloadStyle,
    );
  }
}

Map<String, dynamic> nyaaFiltersToJson(NyaaManualSearchFilters filters) => {
  'exactEpisodeOnly': filters.exactEpisodeOnly,
  'sameSeasonOnly': filters.sameSeasonOnly,
  'preferredLanguageOnly': filters.preferredLanguageOnly,
  'sort': filters.sort.name,
  'resolutions': filters.resolutions.map((r) => r.name).toList(),
  'languageSignals': filters.languageSignals.map((l) => l.name).toList(),
  'batchMode': filters.batchMode.name,
  'minSeeders': filters.minSeeders,
  'minSizeBytes': filters.minSizeBytes,
  'maxSizeBytes': filters.maxSizeBytes,
};

NyaaManualSearchFilters nyaaFiltersFromJson(Map<String, dynamic> json) {
  return NyaaManualSearchFilters(
    exactEpisodeOnly: _boolValue(json['exactEpisodeOnly'], true),
    sameSeasonOnly: _boolValue(json['sameSeasonOnly'], true),
    preferredLanguageOnly: _boolValue(json['preferredLanguageOnly'], true),
    sort: _enumValue(
      NyaaManualSearchSort.values,
      json['sort'],
      NyaaManualSearchSort.smart,
    ),
    resolutions: _enumSet(Resolution.values, json['resolutions'], const {}),
    languageSignals: _enumSet(
      NyaaLanguageSignal.values,
      json['languageSignals'],
      const {},
    ),
    batchMode: _enumValue(
      NyaaBatchMode.values,
      json['batchMode'],
      NyaaBatchMode.any,
    ),
    minSeeders: _nonNegativeIntValue(json['minSeeders'], 0),
    minSizeBytes: _nullableNonNegativeIntValue(json['minSizeBytes']),
    maxSizeBytes: _nullableNonNegativeIntValue(json['maxSizeBytes']),
  );
}

Map<String, dynamic> _mapValue(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

String _stringValue(Object? value, String fallback) {
  if (value is String && value.trim().isNotEmpty) return value;
  return fallback;
}

String? _nullableStringValue(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool _boolValue(Object? value, bool fallback) =>
    value is bool ? value : fallback;

int _intValue(Object? value, int fallback) => value is int ? value : fallback;

int _nonNegativeIntValue(Object? value, int fallback) {
  final parsed = _intValue(value, fallback);
  return parsed < 0 ? fallback : parsed;
}

int? _nullableNonNegativeIntValue(Object? value) {
  if (value is! int || value < 0) return null;
  return value;
}

T _enumValue<T extends Enum>(List<T> values, Object? value, T fallback) {
  if (value is! String) return fallback;
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  return fallback;
}

List<T> _enumList<T extends Enum>(
  List<T> values,
  Object? raw,
  List<T> fallback,
) {
  if (raw is! List) return fallback;
  final parsed = <T>[];
  for (final item in raw) {
    final fallbackValue = values.first;
    final value = _enumValue(values, item, fallbackValue);
    if (item is String && !parsed.contains(value)) parsed.add(value);
  }
  return parsed.isEmpty ? fallback : parsed;
}

Set<T> _enumSet<T extends Enum>(List<T> values, Object? raw, Set<T> fallback) {
  if (raw is! List) return fallback;
  return _enumList(values, raw, fallback.toList()).toSet();
}

List<AnimeSource> _normalizedSourcePriority(List<AnimeSource> priority) {
  final normalized = <AnimeSource>[];
  for (final source in priority) {
    if (!normalized.contains(source)) normalized.add(source);
  }
  for (final source in SourcePreferences.defaultPriority) {
    if (!normalized.contains(source)) normalized.add(source);
  }
  return normalized;
}
