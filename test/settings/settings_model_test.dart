import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/sources/shared/shared.dart';

void main() {
  group('AppSettings', () {
    test('defaults match functional settings plan', () {
      final settings = AppSettings.defaults();

      expect(settings.schemaVersion, AppSettings.currentSchemaVersion);
      expect(settings.content.titleLanguage, TitleLanguagePreference.romaji);
      expect(settings.content.showAdultContent, isFalse);
      expect(settings.content.defaultResolution, Resolution.res1080p);
      expect(settings.content.defaultAudioLanguage, Language.japanese);
      expect(settings.sources.enabledSources, {
        AnimeSource.animepahe,
        AnimeSource.nyaa,
      });
      expect(settings.sources.priority.first, AnimeSource.animepahe);
      expect(settings.storage.imageCacheMaxBytes, 50 * 1024 * 1024);
      expect(settings.anilist.trackerCheckIntervalHours, 1);
      expect(settings.notifications.enabled, isTrue);
      expect(settings.notifications.permissionDenied, isFalse);
      expect(settings.notifications.showWindowsProgressNotification, isFalse);
      expect(
        settings.notifications.downloadStyle,
        DownloadNotificationStyle.batchCompletion,
      );
    });

    test('round trips through json and tolerates unknown fields', () {
      final settings = AppSettings.defaults().copyWith(
        content: const ContentPreferences(
          titleLanguage: TitleLanguagePreference.native,
          showAdultContent: true,
          defaultResolution: Resolution.res720p,
        ),
        sources: const SourcePreferences(
          enabledSources: {AnimeSource.nyaa},
          priority: [AnimeSource.nyaa, AnimeSource.animepahe],
        ),
        notifications: const NotificationPreferences(
          enabled: false,
          permissionDenied: true,
          downloadStyle: DownloadNotificationStyle.episodeCompletion,
          showWindowsProgressNotification: true,
        ),
      );
      final json = settings.toJson()..['futureField'] = 'ignored';

      final decoded = AppSettings.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );

      expect(decoded.content.titleLanguage, TitleLanguagePreference.native);
      expect(decoded.content.showAdultContent, isTrue);
      expect(decoded.content.defaultResolution, Resolution.res720p);
      expect(decoded.sources.enabledSources, {AnimeSource.nyaa});
      expect(decoded.sources.priority.first, AnimeSource.nyaa);
      expect(decoded.notifications.enabled, isFalse);
      expect(decoded.notifications.permissionDenied, isTrue);
      expect(decoded.notifications.showWindowsProgressNotification, isTrue);
      expect(
        decoded.notifications.downloadStyle,
        DownloadNotificationStyle.episodeCompletion,
      );
    });

    test('normalizes invalid HTTP cache age from json', () {
      final settings = AppSettings.fromJson({
        'storage': {'httpCacheMaxAgeSeconds': -1},
      });

      expect(
        settings.storage.httpCacheMaxAgeSeconds,
        StoragePreferences.defaultHttpCacheMaxAgeSeconds,
      );
    });

    test('preserves zero image cache limit as unlimited', () {
      final settings = AppSettings.fromJson({
        'storage': {'imageCacheMaxBytes': 0},
      });

      expect(settings.storage.imageCacheMaxBytes, 0);
    });
  });
}
