import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/request_coordinator.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/platform_paths.dart';
import 'package:senpwai/sources/animepahe.dart' as animepahe;
import 'package:senpwai/sources/nyaa.dart' as nyaa;
import 'package:senpwai/sources/tokyoinsider.dart' as tokyoinsider;
import 'package:senpwai/sources/shared/matcher/animepahe.dart';
import 'package:senpwai/sources/shared/matcher/tokyoinsider.dart';
import 'package:senpwai/sources/shared/matcher/shared.dart';
import 'package:senpwai/sources/shared/shared.dart';

final _log = Logger("senpwai.ui.pages.anime_page.notifier");

// ── Source identity ──────────────────────────────────────────────────────────

enum AnimeSource {
  animepahe,
  tokyoinsider,
  nyaa;

  String get label => switch (this) {
    AnimeSource.animepahe => 'AnimePahe',
    AnimeSource.tokyoinsider => 'TokyoInsider',
    AnimeSource.nyaa => 'Nyaa',
  };

  Color get color => switch (this) {
    AnimeSource.animepahe => const Color(0xFFFF8C00),
    AnimeSource.tokyoinsider => const Color(0xFF43A047),
    AnimeSource.nyaa => const Color(0xFF2196F3),
  };

  String get iconAsset => switch (this) {
    AnimeSource.animepahe => 'assets/images/animepahe-icon.png',
    AnimeSource.tokyoinsider => 'assets/images/tokyoinsider-icon.ico',
    AnimeSource.nyaa => 'assets/images/nyaa-icon.png',
  };
}

// ── Per-source match state ───────────────────────────────────────────────────

enum SourceMatchStatus { loading, matched, failed }

@immutable
class SourceMatchState<T> {
  final SourceMatchStatus status;
  final T? result;
  final String? error;

  const SourceMatchState._({required this.status, this.result, this.error});

  const SourceMatchState.loading() : this._(status: SourceMatchStatus.loading);
  const SourceMatchState.matched(T result)
    : this._(status: SourceMatchStatus.matched, result: result);
  const SourceMatchState.failed(String error)
    : this._(status: SourceMatchStatus.failed, error: error);

  bool get isLoading => status == SourceMatchStatus.loading;
  bool get isMatched => status == SourceMatchStatus.matched;
  bool get isFailed => status == SourceMatchStatus.failed;
}

// ── Aggregate page state ─────────────────────────────────────────────────────

@immutable
class AnimePageState {
  final AnilistAnimeBase anime;

  final SourceMatchState<SourceMatch<animepahe.AnimeResult>> animepaheMatch;
  final SourceMatchState<SourceMatch<tokyoinsider.AnimeResult>>
    tokyoinsiderMatch;
  final SourceMatchState<List<nyaa.AnimeResult>> nyaaMatch;

  final AnimeSource? selectedSource;
  final Resolution selectedResolution;
  final Language selectedLanguage;
  final int startEpisode;
  final int endEpisode;
  final String? downloadFolder;
  final bool trackingEnabled;
  final bool isSubmittingDownload;
  final bool sourceSelectedByUser;

  const AnimePageState({
    required this.anime,
    this.animepaheMatch = const SourceMatchState.loading(),
    this.tokyoinsiderMatch = const SourceMatchState.loading(),
    this.nyaaMatch = const SourceMatchState.loading(),
    this.selectedSource,
    this.selectedResolution = Resolution.res1080p,
    this.selectedLanguage = Language.japanese,
    this.startEpisode = 1,
    this.endEpisode = 1,
    this.downloadFolder,
    this.trackingEnabled = false,
    this.isSubmittingDownload = false,
    this.sourceSelectedByUser = false,
  });

  int get totalEpisodes => anime.episodes ?? 1;

  bool get allSourcesResolved =>
      !animepaheMatch.isLoading &&
      !tokyoinsiderMatch.isLoading &&
      !nyaaMatch.isLoading;

  bool isSourceAvailable(AnimeSource source) => switch (source) {
    AnimeSource.animepahe => animepaheMatch.isMatched,
    AnimeSource.tokyoinsider => tokyoinsiderMatch.isMatched,
    AnimeSource.nyaa => nyaaMatch.isMatched,
  };

  SourceMatchStatus sourceStatus(AnimeSource source) => switch (source) {
    AnimeSource.animepahe => animepaheMatch.status,
    AnimeSource.tokyoinsider => tokyoinsiderMatch.status,
    AnimeSource.nyaa => nyaaMatch.status,
  };

  AnimePageState copyWith({
    SourceMatchState<SourceMatch<animepahe.AnimeResult>>? animepaheMatch,
    SourceMatchState<SourceMatch<tokyoinsider.AnimeResult>>? tokyoinsiderMatch,
    SourceMatchState<List<nyaa.AnimeResult>>? nyaaMatch,
    AnimeSource? selectedSource,
    Resolution? selectedResolution,
    Language? selectedLanguage,
    int? startEpisode,
    int? endEpisode,
    String? downloadFolder,
    bool? trackingEnabled,
    bool? isSubmittingDownload,
    bool? sourceSelectedByUser,
    bool clearSource = false,
  }) {
    return AnimePageState(
      anime: anime,
      animepaheMatch: animepaheMatch ?? this.animepaheMatch,
      tokyoinsiderMatch: tokyoinsiderMatch ?? this.tokyoinsiderMatch,
      nyaaMatch: nyaaMatch ?? this.nyaaMatch,
      selectedSource:
          clearSource ? null : (selectedSource ?? this.selectedSource),
      selectedResolution: selectedResolution ?? this.selectedResolution,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      startEpisode: startEpisode ?? this.startEpisode,
      endEpisode: endEpisode ?? this.endEpisode,
      downloadFolder: downloadFolder ?? this.downloadFolder,
      trackingEnabled: trackingEnabled ?? this.trackingEnabled,
      isSubmittingDownload: isSubmittingDownload ?? this.isSubmittingDownload,
      sourceSelectedByUser: sourceSelectedByUser ?? this.sourceSelectedByUser,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class AnimePageNotifier extends Notifier<AnimePageState> {
  static final provider =
      NotifierProvider.family<AnimePageNotifier, AnimePageState, AnilistAnimeBase>(
        (anime) => AnimePageNotifier._(anime),
      );

  final AnilistAnimeBase _anime;

  AnimePageNotifier._(this._anime);

  @override
  AnimePageState build() {
    final totalEps = _anime.episodes ?? 1;
    final initial = AnimePageState(
      anime: _anime,
      startEpisode: 1,
      endEpisode: totalEps,
      downloadFolder: defaultDownloadsDirectory().path,
    );
    // Fire-and-forget: launch all matchers in parallel.
    Future.microtask(_matchAllSources);
    return initial;
  }

  Future<void> _matchAllSources() async {
    await Future.wait([
      _matchAnimepahe(),
      _matchTokyoinsider(),
      _matchNyaa(),
    ]);
  }

  Future<void> _matchAnimepahe() async {
    try {
      final matcher = AnimepaheMatcher();
      final matches = await matcher.match(state.anime);
      if (matches.isEmpty || matches.first.score < 90) {
        state = state.copyWith(
          animepaheMatch: const SourceMatchState.failed('No match found'),
        );
      } else {
        state = state.copyWith(
          animepaheMatch: SourceMatchState.matched(matches.first),
        );
      }
    } catch (e, stack) {
      _log.warningWithMetadata(
        "AnimePahe matching failed",
        metadata: {"error": e.toString(), "stack": stack.toString()},
      );
      state = state.copyWith(
        animepaheMatch: SourceMatchState.failed(e.toString()),
      );
    }
    _autoSelectSource();
  }

  Future<void> _matchTokyoinsider() async {
    try {
      final matcher = TokyoinsiderMatcher();
      final matches = await matcher.match(state.anime);
      if (matches.isEmpty || matches.first.score < 90) {
        state = state.copyWith(
          tokyoinsiderMatch: const SourceMatchState.failed('No match found'),
        );
      } else {
        state = state.copyWith(
          tokyoinsiderMatch: SourceMatchState.matched(matches.first),
        );
      }
    } catch (e, stack) {
      _log.warningWithMetadata(
        "TokyoInsider matching failed",
        metadata: {"error": e.toString(), "stack": stack.toString()},
      );
      state = state.copyWith(
        tokyoinsiderMatch: SourceMatchState.failed(e.toString()),
      );
    }
    _autoSelectSource();
  }

  Future<void> _matchNyaa() async {
    try {
      final titleCandidates = state.anime.title.toTitleCandidates();
      if (titleCandidates.isEmpty) {
        state = state.copyWith(
          nyaaMatch: const SourceMatchState.failed('No title candidates'),
        );
        _autoSelectSource();
        return;
      }
      final source = nyaa.Source();
      final results = await source.search(
        params: nyaa.SearchParams(term: titleCandidates.first, page: 1),
      );
      if (results.items.isEmpty) {
        state = state.copyWith(
          nyaaMatch: const SourceMatchState.failed('No results found'),
        );
      } else {
        state = state.copyWith(
          nyaaMatch: SourceMatchState.matched(results.items),
        );
      }
    } catch (e, stack) {
      _log.warningWithMetadata(
        "Nyaa matching failed",
        metadata: {"error": e.toString(), "stack": stack.toString()},
      );
      state = state.copyWith(
        nyaaMatch: SourceMatchState.failed(e.toString()),
      );
    }
    _autoSelectSource();
  }

  /// Auto-selects the best available source if the user hasn't manually picked one.
  /// Priority: animepahe → tokyoinsider → nyaa.
  void _autoSelectSource() {
    if (state.sourceSelectedByUser &&
        state.selectedSource != null &&
        state.isSourceAvailable(state.selectedSource!)) {
      return;
    }
    for (final source in AnimeSource.values) {
      if (state.isSourceAvailable(source)) {
        state = state.copyWith(
          selectedSource: source,
          sourceSelectedByUser: false,
        );
        return;
      }
    }
    // If all resolved and none available, clear selection.
    if (state.allSourcesResolved) {
      state = state.copyWith(clearSource: true);
    }
  }

  void selectSource(AnimeSource source) {
    if (!state.isSourceAvailable(source)) return;
    state = state.copyWith(selectedSource: source, sourceSelectedByUser: true);
  }

  void setResolution(Resolution resolution) {
    state = state.copyWith(selectedResolution: resolution);
  }

  void setLanguage(Language language) {
    state = state.copyWith(selectedLanguage: language);
  }

  void setStartEpisode(int ep) {
    state = state.copyWith(startEpisode: ep);
  }

  void setEndEpisode(int ep) {
    state = state.copyWith(endEpisode: ep);
  }

  void setDownloadFolder(String folder) {
    state = state.copyWith(downloadFolder: folder);
  }

  void setTrackingEnabled(bool enabled) {
    state = state.copyWith(trackingEnabled: enabled);
  }

  Future<EnqueuedDownloadsResult> queueDownloads() async {
    final batch = await prepareDownloads();
    return enqueuePreparedDownloads(batch);
  }

  Future<PreparedDownloadBatch> prepareDownloads() async {
    final source = state.selectedSource;
    final folder = state.downloadFolder;
    if (source == null) {
      throw const DownloadUserError(
        title: 'No source selected',
        description: 'Choose a source before starting a download.',
      );
    }
    if (folder == null || folder.trim().isEmpty) {
      throw const DownloadUserError(
        title: 'No folder selected',
        description: 'Choose a download folder before starting a download.',
      );
    }

    state = state.copyWith(isSubmittingDownload: true);
    try {
      final coordinator = AnimeDownloadCoordinator();
      return coordinator.plan(
        request: DownloadRequest(
          anime: state.anime,
          source: _mapRequestedSource(source),
          startEpisode: state.startEpisode,
          endEpisode: state.endEpisode,
          downloadFolder: folder,
          resolution: state.selectedResolution,
          language: state.selectedLanguage,
        ),
        animepaheMatch: state.animepaheMatch.result?.result,
        tokyoinsiderMatch: state.tokyoinsiderMatch.result?.result,
      );
    } finally {
      state = state.copyWith(isSubmittingDownload: false);
    }
  }

  Future<EnqueuedDownloadsResult> enqueuePreparedDownloads(
    PreparedDownloadBatch batch,
  ) {
    return ref.read(DownloadManagerNotifier.provider.notifier).enqueueBatch(batch);
  }

  RequestedDownloadSource _mapRequestedSource(AnimeSource source) => switch (
    source
  ) {
    AnimeSource.animepahe => RequestedDownloadSource.animepahe,
    AnimeSource.tokyoinsider => RequestedDownloadSource.tokyoinsider,
    AnimeSource.nyaa => RequestedDownloadSource.nyaa,
  };
}
