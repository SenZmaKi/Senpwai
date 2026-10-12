import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/anime_download_session.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/source_resolver.dart';
import 'package:senpwai/shared/persistence/app_persistence.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/tracking/models.dart';
import 'package:senpwai/tracking/notifier.dart';

import '../support/support.dart';

void main() {
  setUpAll(setupTestApp);

  test(
    'details starts from tracking; edits stay local until untrack/retrack',
    () async {
      final folder = await Directory.systemTemp.createTemp('tracked-details-');
      addTearDown(() => folder.delete(recursive: true));
      const anime = AnilistAnime(
        id: 1,
        title: AnilistTitle(romaji: 'Example'),
        genres: [],
        episode: 3,
      );
      AppPersistence.trackedAnime = [
        TrackedAnime(
          anilistId: 1,
          animeSnapshot: anime,
          downloadFolder: folder.path,
          preferredSource: AnimeSource.nyaa,
          sourceSelectedByUser: true,
          resolution: Resolution.res720p,
          language: Language.english,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ];
      final provider = AnimeDownloadSessionNotifier.provider(anime);
      final container = ProviderContainer(
        overrides: [
          AnimeDownloadSessionNotifier.provider.overrideWith2(
            (value) => AnimeDownloadSessionNotifier(
              value,
              sourceResolver: _Resolver(),
            ),
          ),
          DownloadManagerNotifier.provider.overrideWith(_Downloads.new),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final initial = container.read(provider);
      expect(initial.selectedResolution, Resolution.res720p);
      expect(initial.selectedLanguage, Language.english);
      expect(initial.selectedSource, AnimeSource.nyaa);
      expect(initial.downloadFolder, folder.path);
      // Allow location/source initialization to finish before editing.
      for (
        var count = 0;
        count < 100 && !container.read(provider).allSourcesResolved;
        count++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(container.read(provider).allSourcesResolved, isTrue);
      final notifier = container.read(provider.notifier);
      notifier.setResolution(Resolution.res480p);
      notifier.setLanguage(Language.japanese);
      expect(
        container
            .read(TrackingNotifier.provider)
            .trackedAnime
            .single
            .resolution,
        Resolution.res720p,
      );
      expect(
        container.read(TrackingNotifier.provider).trackedAnime.single.language,
        Language.english,
      );
      await notifier.setTrackingEnabled(false);
      await notifier.setTrackingEnabled(true);
      final retracked = container
          .read(TrackingNotifier.provider)
          .trackedAnime
          .single;
      expect(retracked.resolution, Resolution.res480p);
      expect(retracked.language, Language.japanese);
      expect(retracked.preferredSource, AnimeSource.nyaa);
      expect(retracked.downloadFolder, folder.path);
    },
  );
}

class _Resolver extends DownloadSourceResolver {
  @override
  Future<ResolvedSourceMatches> resolveAll(AnilistAnimeBase anime) async =>
      const ResolvedSourceMatches(
        animeheavenMatch: SourceMatchState.failed('No match'),
        animepaheMatch: SourceMatchState.failed('No match'),
        tokyoinsiderMatch: SourceMatchState.failed('No match'),
        nyaaMatch: SourceMatchState.matched(true),
      );
}

class _Downloads extends DownloadManagerNotifier {
  @override
  DownloadManagerState build() => const DownloadManagerState();
}
