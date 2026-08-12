import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/persistence/app_persistence.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/tracking/models.dart';
import 'package:senpwai/tracking/tracker.dart';

final _log = Logger('senpwai.tracking.notifier');

class TrackingNotifier extends Notifier<TrackingState> {
  static final provider = NotifierProvider<TrackingNotifier, TrackingState>(
    TrackingNotifier.new,
  );

  final _tracker = AnimeTracker();

  @override
  TrackingState build() => TrackingState(
    trackedAnime: List.unmodifiable(AppPersistence.trackedAnime),
  );

  bool isTracked(int anilistId) => state.isTracked(anilistId);

  Future<void> trackAnime({
    required AnilistAnimeBase anime,
    required AnimeSource? preferredSource,
    required bool sourceSelectedByUser,
    required Resolution resolution,
    required Language language,
    required String downloadFolder,
  }) async {
    final now = DateTime.now();
    final existing = state.trackedById(anime.id);
    final tracked = TrackedAnime(
      anilistId: anime.id,
      animeSnapshot: animeSnapshotFromBase(anime),
      preferredSource: preferredSource,
      sourceSelectedByUser: sourceSelectedByUser && preferredSource != null,
      resolution: resolution,
      language: language,
      downloadFolder: downloadFolder,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      lastCheckedAt: existing?.lastCheckedAt,
      lastError: existing?.lastError,
    );
    final next = [
      for (final item in state.trackedAnime)
        if (item.anilistId == anime.id) tracked else item,
      if (existing == null) tracked,
    ];
    await _commit(next);
  }

  Future<void> untrackAnime(int anilistId) async {
    await _commit([
      for (final item in state.trackedAnime)
        if (item.anilistId != anilistId) item,
    ]);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final next = [...state.trackedAnime];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    await _commit(next);
  }

  Future<void> handleDownloadState(DownloadManagerState downloadState) async {
    final completionBatchIds = {
      for (final tracked in state.trackedAnime)
        if (tracked.completionBatchId != null) tracked.completionBatchId!,
    };
    if (completionBatchIds.isEmpty) return;

    final completedBatchIds = <String>{};
    for (final batchId in completionBatchIds) {
      final items = downloadState.items
          .where((item) => item.batchId == batchId)
          .toList();
      if (items.isNotEmpty &&
          items.every((item) => item.status == DownloadQueueStatus.completed)) {
        completedBatchIds.add(batchId);
      }
    }
    if (completedBatchIds.isEmpty) return;

    final removed = [
      for (final tracked in state.trackedAnime)
        if (completedBatchIds.contains(tracked.completionBatchId)) tracked,
    ];
    await _commit([
      for (final tracked in state.trackedAnime)
        if (!completedBatchIds.contains(tracked.completionBatchId)) tracked,
    ]);
    for (final tracked in removed) {
      _emitEvent(
        TrackingEvent.create(
          kind: TrackingEventKind.finishedTracking,
          level: TrackingEventLevel.info,
          title: 'Finished tracking',
          description:
              '${tracked.animeSnapshot.title.display} completed and was removed from tracked anime.',
        ),
      );
    }
  }

  Future<void> checkNow() async {
    final intervalHours = ref
        .read(AppSettingsNotifier.provider)
        .anilist
        .trackerCheckIntervalHours;
    if (intervalHours == 0 ||
        state.checkInProgress ||
        state.trackedAnime.isEmpty) {
      return;
    }
    final startedAt = DateTime.now();
    state = state.copyWith(
      checkInProgress: true,
      lastCheckStartedAt: startedAt,
    );
    try {
      final result = await _tracker.check(
        trackedAnime: state.trackedAnime,
        settings: ref.read(AppSettingsNotifier.provider),
        downloadState: ref.read(DownloadManagerNotifier.provider),
        enqueueBatch: (batch) => ref
            .read(DownloadManagerNotifier.provider.notifier)
            .enqueueBatch(batch),
      );
      await _commit(
        result.trackedAnime,
        checkInProgress: false,
        lastCheckStartedAt: startedAt,
        lastCheckCompletedAt: DateTime.now(),
      );
      if (result.queuedEpisodeCount > 0) {
        _log.infoWithMetadata(
          'Tracker queued new episodes',
          metadata: {
            'checkedCount': result.checkedCount,
            'queuedBatchCount': result.queuedBatchCount,
            'queuedEpisodeCount': result.queuedEpisodeCount,
          },
        );
      }
      for (final event in result.events) {
        _emitEvent(event);
      }
    } on Object catch (error, stackTrace) {
      _log.warningWithMetadata(
        'Tracker check failed',
        metadata: {'error': '$error', 'stackTrace': '$stackTrace'},
      );
      state = state.copyWith(
        checkInProgress: false,
        lastCheckCompletedAt: DateTime.now(),
      );
    }
  }

  Future<void> _commit(
    List<TrackedAnime> trackedAnime, {
    bool? checkInProgress,
    DateTime? lastCheckStartedAt,
    DateTime? lastCheckCompletedAt,
  }) async {
    final next = List<TrackedAnime>.unmodifiable(trackedAnime);
    state = state.copyWith(
      trackedAnime: next,
      checkInProgress: checkInProgress,
      lastCheckStartedAt: lastCheckStartedAt,
      lastCheckCompletedAt: lastCheckCompletedAt,
    );
    await AppPersistence.trackingRepository.save(next);
    AppPersistence.trackedAnime = next;
  }

  void _emitEvent(TrackingEvent event) {
    state = state.copyWith(latestEvent: event);
  }
}

class TrackingScheduler extends Notifier<int> {
  static final provider = NotifierProvider<TrackingScheduler, int>(
    TrackingScheduler.new,
  );

  Timer? _timer;

  @override
  int build() {
    final intervalHours = ref.read(
      AppSettingsNotifier.provider.select(
        (settings) => settings.anilist.trackerCheckIntervalHours,
      ),
    );
    _schedule(intervalHours);
    ref.listen(
      AppSettingsNotifier.provider.select(
        (settings) => settings.anilist.trackerCheckIntervalHours,
      ),
      (_, hours) => _schedule(hours),
    );
    if (intervalHours > 0) {
      Future.microtask(() {
        unawaited(ref.read(TrackingNotifier.provider.notifier).checkNow());
      });
    }
    ref.onDispose(() {
      _timer?.cancel();
    });
    return 0;
  }

  void _schedule(int intervalHours) {
    _timer?.cancel();
    if (intervalHours <= 0) return;
    _timer = Timer.periodic(Duration(hours: intervalHours), (_) {
      unawaited(ref.read(TrackingNotifier.provider.notifier).checkNow());
      state += 1;
    });
  }
}
