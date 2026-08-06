import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
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

enum CardViewMode { poster, landscape, table }

enum DownloadNotificationStyle {
  batchCompletion,
  episodeCompletion;

  String get label => switch (this) {
    DownloadNotificationStyle.batchCompletion => 'Batch completion',
    DownloadNotificationStyle.episodeCompletion => 'Episode completion',
  };
}

enum TorrentEncryptionMode {
  enabled,
  forced,
  disabled;

  String get label => switch (this) {
    TorrentEncryptionMode.enabled => 'Enabled',
    TorrentEncryptionMode.forced => 'Forced',
    TorrentEncryptionMode.disabled => 'Disabled',
  };
}

enum TorrentSeedingMode {
  disabled,
  untilTarget,
  indefinitely;

  String get label => switch (this) {
    TorrentSeedingMode.disabled => 'Don\'t seed',
    TorrentSeedingMode.untilTarget => 'Seed until target',
    TorrentSeedingMode.indefinitely => 'Seed indefinitely',
  };
}

enum TorrentProxyMode {
  none,
  socks4,
  socks5,
  socks5Password,
  http,
  httpPassword;

  String get label => switch (this) {
    TorrentProxyMode.none => 'None',
    TorrentProxyMode.socks4 => 'SOCKS4',
    TorrentProxyMode.socks5 => 'SOCKS5',
    TorrentProxyMode.socks5Password => 'SOCKS5 + password',
    TorrentProxyMode.http => 'HTTP',
    TorrentProxyMode.httpPassword => 'HTTP + password',
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
  final WindowPreferences window;

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
    this.window = const WindowPreferences(),
  });

  factory AppSettings.defaults() => AppSettingsDefaults.settings;

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
    window: WindowPreferences.fromJson(_mapValue(json['window'])),
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
    'window': window.toJson(),
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
    WindowPreferences? window,
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
      window: window ?? this.window,
    );
  }
}

/// Device-independent application preferences used as the reset baseline.
class AppSettingsDefaults {
  const AppSettingsDefaults._();

  static const settings = AppSettings();
}

@immutable
class AppearancePreferences {
  final BrightnessMode brightnessMode;
  final SenpwaiThemePreset themePreset;
  final String displayFontFamily;
  final String bodyFontFamily;
  final CardViewMode cardViewMode;

  const AppearancePreferences({
    this.brightnessMode = BrightnessMode.system,
    this.themePreset = SenpwaiThemePreset.defaultTheme,
    this.displayFontFamily = 'Orbitron',
    this.bodyFontFamily = 'Exo 2',
    this.cardViewMode = CardViewMode.poster,
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
        cardViewMode: _enumValue(
          CardViewMode.values,
          json['cardViewMode'],
          CardViewMode.poster,
        ),
      );

  Map<String, dynamic> toJson() => {
    'brightnessMode': brightnessMode.name,
    'themePreset': themePreset.name,
    'displayFontFamily': displayFontFamily,
    'bodyFontFamily': bodyFontFamily,
    'cardViewMode': cardViewMode.name,
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
    CardViewMode? cardViewMode,
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
      cardViewMode: cardViewMode ?? this.cardViewMode,
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
  final List<String> rootDirectories;
  final List<CustomAnimeFolder> customAnimeFolders;
  final int maxDownloadBytesPerSecond;
  final int maxActiveDownloads;
  final bool skipFillers;

  const DownloadPreferences({
    this.defaultRootDirectory,
    this.rootDirectories = const [],
    this.customAnimeFolders = const [],
    this.maxDownloadBytesPerSecond = 0,
    this.maxActiveDownloads = 1,
    this.skipFillers = false,
  });

  factory DownloadPreferences.fromJson(Map<String, dynamic> json) {
    final legacyRoot = _nullableStringValue(json['defaultRootDirectory']);
    final rootDirectories = _stringListValue(json['rootDirectories']);
    return DownloadPreferences(
      defaultRootDirectory: legacyRoot,
      rootDirectories: rootDirectories.isNotEmpty
          ? rootDirectories
          : [if (legacyRoot != null) legacyRoot],
      customAnimeFolders: _mapListValue(json['customAnimeFolders'])
          .map(CustomAnimeFolder.fromJson)
          .where((folder) => folder.animeTitle.trim().isNotEmpty)
          .toList(),
      maxDownloadBytesPerSecond: _nonNegativeIntValue(
        json['maxDownloadBytesPerSecond'],
        0,
      ),
      maxActiveDownloads: _queueLimitValue(json['maxActiveDownloads'], 1),
      skipFillers: _boolValue(json['skipFillers'], false),
    );
  }

  Map<String, dynamic> toJson() => {
    'defaultRootDirectory': effectiveRootDirectories.firstOrNull,
    'rootDirectories': rootDirectories,
    'customAnimeFolders': customAnimeFolders
        .map((folder) => folder.toJson())
        .toList(),
    'maxDownloadBytesPerSecond': maxDownloadBytesPerSecond,
    'maxActiveDownloads': maxActiveDownloads,
    'skipFillers': skipFillers,
  };

  List<String> get effectiveRootDirectories {
    if (rootDirectories.isNotEmpty) return rootDirectories;
    return [if (defaultRootDirectory != null) defaultRootDirectory!];
  }

  DownloadPreferences copyWith({
    String? defaultRootDirectory,
    List<String>? rootDirectories,
    List<CustomAnimeFolder>? customAnimeFolders,
    int? maxDownloadBytesPerSecond,
    int? maxActiveDownloads,
    bool? skipFillers,
    bool clearDefaultRootDirectory = false,
  }) {
    final nextRootDirectories = rootDirectories ?? this.rootDirectories;
    return DownloadPreferences(
      defaultRootDirectory: clearDefaultRootDirectory
          ? null
          : (defaultRootDirectory ??
                nextRootDirectories.firstOrNull ??
                this.defaultRootDirectory),
      rootDirectories: nextRootDirectories,
      customAnimeFolders: customAnimeFolders ?? this.customAnimeFolders,
      maxDownloadBytesPerSecond:
          maxDownloadBytesPerSecond ?? this.maxDownloadBytesPerSecond,
      maxActiveDownloads: maxActiveDownloads ?? this.maxActiveDownloads,
      skipFillers: skipFillers ?? this.skipFillers,
    );
  }
}

@immutable
class CustomAnimeFolder {
  final String animeTitle;
  final String folder;

  const CustomAnimeFolder({required this.animeTitle, required this.folder});

  factory CustomAnimeFolder.fromJson(Map<String, dynamic> json) =>
      CustomAnimeFolder(
        animeTitle: _stringValue(json['animeTitle'], ''),
        folder: _stringValue(json['folder'], ''),
      );

  Map<String, dynamic> toJson() => {'animeTitle': animeTitle, 'folder': folder};
}

@immutable
class SourcePreferences {
  static const defaultEnabledSources = {
    AnimeSource.animepahe,
    AnimeSource.nyaa,
  };

  static const defaultPriority = [
    AnimeSource.animepahe,
    AnimeSource.tokyoinsider,
    AnimeSource.nyaa,
  ];

  final Set<AnimeSource> enabledSources;
  final List<AnimeSource> priority;
  final NyaaManualSearchFilters nyaaDefaultFilters;
  final bool skipNyaaReviewWhenUnambiguous;

  const SourcePreferences({
    this.enabledSources = defaultEnabledSources,
    this.priority = defaultPriority,
    this.nyaaDefaultFilters = const NyaaManualSearchFilters(),
    this.skipNyaaReviewWhenUnambiguous = false,
  });

  factory SourcePreferences.fromJson(Map<String, dynamic> json) {
    final enabled = _enumSet(
      AnimeSource.values,
      json['enabledSources'],
      defaultEnabledSources,
    );
    final priority = _normalizedSourcePriority(
      _enumList(AnimeSource.values, json['priority'], defaultPriority),
    );
    return SourcePreferences(
      enabledSources: enabled.isEmpty ? defaultEnabledSources : enabled,
      priority: priority,
      nyaaDefaultFilters: nyaaFiltersFromJson(
        _mapValue(json['nyaaDefaultFilters']),
      ),
      skipNyaaReviewWhenUnambiguous: _boolValue(
        json['skipNyaaReviewWhenUnambiguous'],
        false,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabledSources': enabledSources.map((source) => source.name).toList(),
    'priority': priority.map((source) => source.name).toList(),
    'nyaaDefaultFilters': nyaaFiltersToJson(nyaaDefaultFilters),
    'skipNyaaReviewWhenUnambiguous': skipNyaaReviewWhenUnambiguous,
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
    bool? skipNyaaReviewWhenUnambiguous,
  }) {
    final nextEnabled = enabledSources ?? this.enabledSources;
    return SourcePreferences(
      enabledSources: nextEnabled.isEmpty ? this.enabledSources : nextEnabled,
      priority: priority == null
          ? this.priority
          : _normalizedSourcePriority(priority),
      nyaaDefaultFilters: nyaaDefaultFilters ?? this.nyaaDefaultFilters,
      skipNyaaReviewWhenUnambiguous:
          skipNyaaReviewWhenUnambiguous ?? this.skipNyaaReviewWhenUnambiguous,
    );
  }
}

@immutable
class TorrentPreferences {
  final int maxDownloadBytesPerSecond;
  final int maxUploadBytesPerSecond;
  final int maxActiveDownloads;
  final int maxActiveSeeds;
  final int maxConnections;
  final int seedRatioLimit;
  final int seedTimeLimitMinutes;
  final TorrentSeedingMode seedingMode;
  final int torrentPort;
  final TorrentEncryptionMode encryptionMode;
  final bool anonymousMode;
  final bool enableIncomingTcp;
  final bool enableIncomingUtp;
  final bool enableOutgoingTcp;
  final bool enableOutgoingUtp;
  final bool enableDht;
  final bool enableLsd;
  final bool enableUpnp;
  final bool enableNatPmp;
  final TorrentProxyMode proxyMode;
  final String proxyHost;
  final int proxyPort;
  final String proxyUsername;
  final String proxyPassword;

  const TorrentPreferences({
    this.maxDownloadBytesPerSecond = 0,
    this.maxUploadBytesPerSecond = 0,
    this.maxActiveDownloads = 1,
    this.maxActiveSeeds = 5,
    this.maxConnections = 200,
    this.seedRatioLimit = 200,
    this.seedTimeLimitMinutes = 24 * 60,
    this.seedingMode = TorrentSeedingMode.untilTarget,
    this.torrentPort = 6881,
    this.encryptionMode = TorrentEncryptionMode.enabled,
    this.anonymousMode = false,
    this.enableIncomingTcp = true,
    this.enableIncomingUtp = true,
    this.enableOutgoingTcp = true,
    this.enableOutgoingUtp = true,
    this.enableDht = true,
    this.enableLsd = true,
    this.enableUpnp = true,
    this.enableNatPmp = true,
    this.proxyMode = TorrentProxyMode.none,
    this.proxyHost = '',
    this.proxyPort = 0,
    this.proxyUsername = '',
    this.proxyPassword = '',
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
        maxActiveDownloads: _queueLimitValue(json['maxActiveDownloads'], 1),
        maxActiveSeeds: _queueLimitValue(json['maxActiveSeeds'], 5),
        maxConnections: _positiveIntValue(json['maxConnections'], 200),
        seedRatioLimit: _nonNegativeIntValue(json['seedRatioLimit'], 200),
        seedTimeLimitMinutes: _nonNegativeIntValue(
          json['seedTimeLimitMinutes'],
          24 * 60,
        ),
        seedingMode: _enumValue(
          TorrentSeedingMode.values,
          json['seedingMode'],
          TorrentSeedingMode.untilTarget,
        ),
        torrentPort: _portValue(json['torrentPort'], 6881),
        encryptionMode: _enumValue(
          TorrentEncryptionMode.values,
          json['encryptionMode'],
          TorrentEncryptionMode.enabled,
        ),
        anonymousMode: _boolValue(json['anonymousMode'], false),
        enableIncomingTcp: _boolValue(json['enableIncomingTcp'], true),
        enableIncomingUtp: _boolValue(json['enableIncomingUtp'], true),
        enableOutgoingTcp: _boolValue(json['enableOutgoingTcp'], true),
        enableOutgoingUtp: _boolValue(json['enableOutgoingUtp'], true),
        enableDht: _boolValue(json['enableDht'], true),
        enableLsd: _boolValue(json['enableLsd'], true),
        enableUpnp: _boolValue(json['enableUpnp'], true),
        enableNatPmp: _boolValue(json['enableNatPmp'], true),
      );

  Map<String, dynamic> toJson() => {
    'maxDownloadBytesPerSecond': maxDownloadBytesPerSecond,
    'maxUploadBytesPerSecond': maxUploadBytesPerSecond,
    'maxActiveDownloads': maxActiveDownloads,
    'maxActiveSeeds': maxActiveSeeds,
    'maxConnections': maxConnections,
    'seedRatioLimit': seedRatioLimit,
    'seedTimeLimitMinutes': seedTimeLimitMinutes,
    'seedingMode': seedingMode.name,
    'torrentPort': torrentPort,
    'encryptionMode': encryptionMode.name,
    'anonymousMode': anonymousMode,
    'enableIncomingTcp': enableIncomingTcp,
    'enableIncomingUtp': enableIncomingUtp,
    'enableOutgoingTcp': enableOutgoingTcp,
    'enableOutgoingUtp': enableOutgoingUtp,
    'enableDht': enableDht,
    'enableLsd': enableLsd,
    'enableUpnp': enableUpnp,
    'enableNatPmp': enableNatPmp,
  };

  TorrentPreferences copyWith({
    int? maxDownloadBytesPerSecond,
    int? maxUploadBytesPerSecond,
    int? maxActiveDownloads,
    int? maxActiveSeeds,
    int? maxConnections,
    int? seedRatioLimit,
    int? seedTimeLimitMinutes,
    TorrentSeedingMode? seedingMode,
    int? torrentPort,
    TorrentEncryptionMode? encryptionMode,
    bool? anonymousMode,
    bool? enableIncomingTcp,
    bool? enableIncomingUtp,
    bool? enableOutgoingTcp,
    bool? enableOutgoingUtp,
    bool? enableDht,
    bool? enableLsd,
    bool? enableUpnp,
    bool? enableNatPmp,
    TorrentProxyMode? proxyMode,
    String? proxyHost,
    int? proxyPort,
    String? proxyUsername,
    String? proxyPassword,
  }) {
    return TorrentPreferences(
      maxDownloadBytesPerSecond:
          maxDownloadBytesPerSecond ?? this.maxDownloadBytesPerSecond,
      maxUploadBytesPerSecond:
          maxUploadBytesPerSecond ?? this.maxUploadBytesPerSecond,
      maxActiveDownloads: maxActiveDownloads ?? this.maxActiveDownloads,
      maxActiveSeeds: maxActiveSeeds ?? this.maxActiveSeeds,
      maxConnections: maxConnections ?? this.maxConnections,
      seedRatioLimit: seedRatioLimit ?? this.seedRatioLimit,
      seedTimeLimitMinutes: seedTimeLimitMinutes ?? this.seedTimeLimitMinutes,
      seedingMode: seedingMode ?? this.seedingMode,
      torrentPort: torrentPort ?? this.torrentPort,
      encryptionMode: encryptionMode ?? this.encryptionMode,
      anonymousMode: anonymousMode ?? this.anonymousMode,
      enableIncomingTcp: enableIncomingTcp ?? this.enableIncomingTcp,
      enableIncomingUtp: enableIncomingUtp ?? this.enableIncomingUtp,
      enableOutgoingTcp: enableOutgoingTcp ?? this.enableOutgoingTcp,
      enableOutgoingUtp: enableOutgoingUtp ?? this.enableOutgoingUtp,
      enableDht: enableDht ?? this.enableDht,
      enableLsd: enableLsd ?? this.enableLsd,
      enableUpnp: enableUpnp ?? this.enableUpnp,
      enableNatPmp: enableNatPmp ?? this.enableNatPmp,
      proxyMode: proxyMode ?? this.proxyMode,
      proxyHost: proxyHost ?? this.proxyHost,
      proxyPort: proxyPort ?? this.proxyPort,
      proxyUsername: proxyUsername ?? this.proxyUsername,
      proxyPassword: proxyPassword ?? this.proxyPassword,
    );
  }
}

@immutable
class AnilistPreferences {
  static const defaultTrackerCheckIntervalHours = 1;

  final int trackerCheckIntervalHours;

  const AnilistPreferences({
    this.trackerCheckIntervalHours = defaultTrackerCheckIntervalHours,
  });

  factory AnilistPreferences.fromJson(Map<String, dynamic> json) =>
      AnilistPreferences(
        trackerCheckIntervalHours: _nonNegativeIntValue(
          json['trackerCheckIntervalHours'],
          defaultTrackerCheckIntervalHours,
        ),
      );

  Map<String, dynamic> toJson() => {
    'trackerCheckIntervalHours': trackerCheckIntervalHours,
  };

  AnilistPreferences copyWith({int? trackerCheckIntervalHours}) =>
      AnilistPreferences(
        trackerCheckIntervalHours:
            trackerCheckIntervalHours ?? this.trackerCheckIntervalHours,
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
    this.downloadStyle = DownloadNotificationStyle.batchCompletion,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        enabled: _boolValue(json['enabled'], true),
        permissionDenied: _boolValue(json['permissionDenied'], false),
        downloadStyle: _downloadNotificationStyleValue(json['downloadStyle']),
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

@immutable
class WindowPreferences {
  final bool alwaysOnTop;
  final bool closeToTray;
  final bool startMaximized;
  final bool startFullScreen;
  final bool launchAtStartup;

  const WindowPreferences({
    this.alwaysOnTop = false,
    this.closeToTray = false,
    this.startMaximized = true,
    this.startFullScreen = false,
    this.launchAtStartup = false,
  });

  factory WindowPreferences.fromJson(Map<String, dynamic> json) =>
      WindowPreferences(
        alwaysOnTop: _boolValue(json['alwaysOnTop'], false),
        closeToTray: _boolValue(json['closeToTray'], false),
        startMaximized: _boolValue(json['startMaximized'], true),
        startFullScreen: _boolValue(json['startFullScreen'], false),
        launchAtStartup: _boolValue(json['launchAtStartup'], false),
      );

  Map<String, dynamic> toJson() => {
    'alwaysOnTop': alwaysOnTop,
    'closeToTray': closeToTray,
    'startMaximized': startMaximized,
    'startFullScreen': startFullScreen,
    'launchAtStartup': launchAtStartup,
  };

  WindowPreferences copyWith({
    bool? alwaysOnTop,
    bool? closeToTray,
    bool? startMaximized,
    bool? startFullScreen,
    bool? launchAtStartup,
  }) {
    return WindowPreferences(
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      closeToTray: closeToTray ?? this.closeToTray,
      startMaximized: startMaximized ?? this.startMaximized,
      startFullScreen: startFullScreen ?? this.startFullScreen,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
    );
  }
}

DownloadNotificationStyle _downloadNotificationStyleValue(Object? value) {
  return switch (value) {
    'episodeCompletion' ||
    'eachDownload' => DownloadNotificationStyle.episodeCompletion,
    'batchCompletion' ||
    'batchSummary' ||
    'completionOnly' => DownloadNotificationStyle.batchCompletion,
    _ => DownloadNotificationStyle.batchCompletion,
  };
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

List<Map<String, dynamic>> _mapListValue(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map<String, dynamic>) item,
  ];
}

List<String> _stringListValue(Object? value) {
  if (value is! List) return const [];
  final strings = <String>[];
  for (final item in value) {
    final parsed = _nullableStringValue(item);
    if (parsed != null && !strings.contains(parsed)) strings.add(parsed);
  }
  return strings;
}

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

int _positiveIntValue(Object? value, int fallback) {
  final parsed = _intValue(value, fallback);
  return parsed <= 0 ? fallback : parsed;
}

int _queueLimitValue(Object? value, int fallback) {
  final parsed = value is num ? value.toInt() : fallback;
  return parsed < -1 ? fallback : parsed;
}

int _portValue(Object? value, int fallback) {
  final parsed = _intValue(value, fallback);
  return parsed < 0 || parsed > 65535 ? fallback : parsed;
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
