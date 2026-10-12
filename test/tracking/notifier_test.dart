import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/persistence/app_persistence.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/tracking/models.dart';
import 'package:senpwai/tracking/notifier.dart';
import 'package:senpwai/tracking/repository.dart';
import 'package:senpwai/tracking/tracker.dart';

import '../support/support.dart';

void main() {
  setUpAll(setupTestApp);
  setUp(() => AppPersistence.trackedAnime = [_tracked()]);

  test('concurrent edits merge and persist without losing fields', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(TrackingNotifier.provider.notifier);
    await Future.wait([
      notifier.updatePreferences(1, resolution: Resolution.res720p),
      notifier.updatePreferences(1, language: Language.english),
      notifier.updateSource(1, AnimeSource.nyaa),
    ]);
    final current = container
        .read(TrackingNotifier.provider)
        .trackedAnime
        .single;
    final saved = (await AppPersistence.trackingRepository.load()).single;
    for (final item in [current, saved]) {
      expect(item.resolution, Resolution.res720p);
      expect(item.language, Language.english);
      expect(item.preferredSource, AnimeSource.nyaa);
      expect(item.completionBatchId, isNull);
    }
  });

  test('source changes invalidate the previous completion batch', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(TrackingNotifier.provider.notifier)
        .updateSource(1, AnimeSource.nyaa);
    expect(
      container
          .read(TrackingNotifier.provider)
          .trackedAnime
          .single
          .completionBatchId,
      isNull,
    );
  });

  test('save failure retains state and later saves can recover', () async {
    final repository = _FailingRepository();
    final container = ProviderContainer(
      overrides: [
        TrackingNotifier.provider.overrideWith(
          () => TrackingNotifier(repository: repository),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(TrackingNotifier.provider.notifier);
    await expectLater(
      notifier.updatePreferences(1, language: Language.english),
      throwsStateError,
    );
    expect(
      container.read(TrackingNotifier.provider).trackedAnime.single.language,
      Language.japanese,
    );
    expect(AppPersistence.trackedAnime.single.language, Language.japanese);
    repository.fail = false;
    await notifier.updatePreferences(1, language: Language.english);
    expect(
      container.read(TrackingNotifier.provider).trackedAnime.single.language,
      Language.english,
    );
  });

  test(
    'disabling during preparation prevents enqueue and stale completion updates',
    () async {
      final started = Completer<void>();
      final prepared = Completer<TrackingPreparedBatch>();
      final tracker = AnimeTracker(
        loadAnime: (_) async => const AnilistAnime(
          id: 1,
          title: AnilistTitle(romaji: 'Example'),
          genres: [],
          episode: 3,
        ),
        resolveLastEpisode: (_, _) async => 1,
        prepareBatch: (_, _, _, _, _, _) {
          started.complete();
          return prepared.future;
        },
      );
      final settings = _Settings();
      final downloads = _Downloads();
      final container = ProviderContainer(
        overrides: [
          TrackingNotifier.provider.overrideWith(
            () => TrackingNotifier(tracker: tracker),
          ),
          AppSettingsNotifier.provider.overrideWith(() => settings),
          DownloadManagerNotifier.provider.overrideWith(() => downloads),
        ],
      );
      addTearDown(container.dispose);
      final operation = container
          .read(TrackingNotifier.provider.notifier)
          .checkNow();
      await started.future;
      settings.disable();
      prepared.complete(
        TrackingPreparedBatch(
          source: AnimeSource.nyaa,
          downloadFolder: '/anime',
          batch: PreparedDownloadBatch(
            jobs: [
              const PreparedHttpDownloadJob(
                source: AnimeSource.nyaa,
                animeTitle: 'Example',
                displayTitle: 'Example - 02.mkv',
                destinationDirectory: '/anime',
                totalBytes: 10,
                resolvedUrl: 'https://example.com/file',
                fileName: 'Example - 02.mkv',
              ),
            ],
          ),
        ),
      );
      await operation;
      expect(downloads.enqueued, 0);
      expect(
        container
            .read(TrackingNotifier.provider)
            .trackedAnime
            .single
            .preferredSource,
        AnimeSource.animepahe,
      );
      expect(
        container.read(TrackingNotifier.provider).checkInProgress,
        isFalse,
      );
    },
  );
}

TrackedAnime _tracked() => TrackedAnime(
  anilistId: 1,
  animeSnapshot: const AnilistAnime(
    id: 1,
    title: AnilistTitle(romaji: 'Example'),
    genres: [],
  ),
  downloadFolder: '/anime',
  resolution: Resolution.res1080p,
  language: Language.japanese,
  preferredSource: AnimeSource.animepahe,
  sourceSelectedByUser: true,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  completionBatchId: 'old-batch',
);

class _Settings extends AppSettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
  void disable() => state = state.copyWith(
    anilist: state.anilist.copyWith(trackerCheckIntervalHours: 0),
  );
}

class _Downloads extends DownloadManagerNotifier {
  int enqueued = 0;
  @override
  DownloadManagerState build() => const DownloadManagerState();
  @override
  Future<EnqueuedDownloadsResult> enqueueBatch(
    PreparedDownloadBatch batch,
  ) async {
    enqueued++;
    return const EnqueuedDownloadsResult(queuedCount: 1);
  }
}

class _FailingRepository extends TrackingRepository {
  bool fail = true;
  _FailingRepository() : super(file: File('unused'));
  @override
  Future<void> save(List<TrackedAnime> trackedAnime) async {
    if (fail) throw StateError('Disk unavailable');
  }
}
