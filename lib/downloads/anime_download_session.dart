import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/request_coordinator.dart';
import 'package:senpwai/downloads/source_resolver.dart';
import 'package:senpwai/downloads/target_path_planner.dart';
import 'package:senpwai/shared/platform_paths.dart';
import 'package:senpwai/sources/shared/shared.dart';

enum DownloadSubmissionStage { idle, planning, reviewing, queueing }

extension DownloadSubmissionStageExtension on DownloadSubmissionStage {
  String label({required bool hasSource}) => switch (this) {
    DownloadSubmissionStage.idle =>
      hasSource ? 'Download' : 'No source available',
    DownloadSubmissionStage.planning => 'Planning download...',
    DownloadSubmissionStage.reviewing => 'Reviewing plan...',
    DownloadSubmissionStage.queueing => 'Queueing download...',
  };
}

@immutable
class AnimeDownloadSessionState {
  final AnilistAnimeBase anime;
  final SourceMatchState<AnimepaheSourceMatch> animepaheMatch;
  final SourceMatchState<TokyoinsiderSourceMatch> tokyoinsiderMatch;
  final SourceMatchState<bool> nyaaMatch;
  final AnimeSource? selectedSource;
  final Resolution selectedResolution;
  final Language selectedLanguage;
  final int startEpisode;
  final int endEpisode;
  final String? downloadFolder;
  final String resolvedDownloadTitle;
  final bool trackingEnabled;
  final DownloadSubmissionStage submissionStage;
  final bool sourceSelectedByUser;
  final bool downloadFolderSelectedByUser;
  final bool endEpisodeUsesLatest;

  const AnimeDownloadSessionState({
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
    this.resolvedDownloadTitle = '',
    this.trackingEnabled = false,
    this.submissionStage = DownloadSubmissionStage.idle,
    this.sourceSelectedByUser = false,
    this.downloadFolderSelectedByUser = false,
    this.endEpisodeUsesLatest = true,
  });

  int get totalEpisodes => anime.episodes ?? 1;

  bool get allSourcesResolved =>
      !animepaheMatch.isLoading &&
      !tokyoinsiderMatch.isLoading &&
      !nyaaMatch.isLoading;

  bool get isSubmittingDownload =>
      submissionStage != DownloadSubmissionStage.idle;

  String get submitButtonLabel =>
      submissionStage.label(hasSource: selectedSource != null);

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

  AnimeDownloadSessionState copyWith({
    SourceMatchState<AnimepaheSourceMatch>? animepaheMatch,
    SourceMatchState<TokyoinsiderSourceMatch>? tokyoinsiderMatch,
    SourceMatchState<bool>? nyaaMatch,
    AnimeSource? selectedSource,
    Resolution? selectedResolution,
    Language? selectedLanguage,
    int? startEpisode,
    int? endEpisode,
    String? downloadFolder,
    String? resolvedDownloadTitle,
    bool? trackingEnabled,
    DownloadSubmissionStage? submissionStage,
    bool? sourceSelectedByUser,
    bool? downloadFolderSelectedByUser,
    bool? endEpisodeUsesLatest,
    bool clearSource = false,
  }) {
    return AnimeDownloadSessionState(
      anime: anime,
      animepaheMatch: animepaheMatch ?? this.animepaheMatch,
      tokyoinsiderMatch: tokyoinsiderMatch ?? this.tokyoinsiderMatch,
      nyaaMatch: nyaaMatch ?? this.nyaaMatch,
      selectedSource: clearSource
          ? null
          : (selectedSource ?? this.selectedSource),
      selectedResolution: selectedResolution ?? this.selectedResolution,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      startEpisode: startEpisode ?? this.startEpisode,
      endEpisode: endEpisode ?? this.endEpisode,
      downloadFolder: downloadFolder ?? this.downloadFolder,
      resolvedDownloadTitle:
          resolvedDownloadTitle ?? this.resolvedDownloadTitle,
      trackingEnabled: trackingEnabled ?? this.trackingEnabled,
      submissionStage: submissionStage ?? this.submissionStage,
      sourceSelectedByUser: sourceSelectedByUser ?? this.sourceSelectedByUser,
      downloadFolderSelectedByUser:
          downloadFolderSelectedByUser ?? this.downloadFolderSelectedByUser,
      endEpisodeUsesLatest: endEpisodeUsesLatest ?? this.endEpisodeUsesLatest,
    );
  }
}

class AnimeDownloadSessionNotifier extends Notifier<AnimeDownloadSessionState> {
  static final provider =
      NotifierProvider.family<
        AnimeDownloadSessionNotifier,
        AnimeDownloadSessionState,
        AnilistAnimeBase
      >((anime) => AnimeDownloadSessionNotifier._(anime));

  final AnilistAnimeBase _anime;
  final DownloadSourceResolver _sourceResolver;
  final AnimeDownloadCoordinator _coordinator;
  final DownloadTargetPlanner _targetPlanner;

  AnimeDownloadSessionNotifier._(
    this._anime, {
    DownloadSourceResolver? sourceResolver,
    AnimeDownloadCoordinator? coordinator,
    DownloadTargetPlanner? targetPlanner,
  }) : _sourceResolver = sourceResolver ?? DownloadSourceResolver(),
       _coordinator = coordinator ?? AnimeDownloadCoordinator(),
       _targetPlanner = targetPlanner ?? const DownloadTargetPlanner();

  @override
  AnimeDownloadSessionState build() {
    Future.microtask(_initialize);
    return AnimeDownloadSessionState(
      anime: _anime,
      startEpisode: 1,
      endEpisode: _anime.episodes ?? 1,
      endEpisodeUsesLatest: true,
    );
  }

  AnimeDownloadSessionState get currentState => state;

  Future<void> _initialize() async {
    await Future.wait([_resolveInitialLocation(), _resolveSources()]);
  }

  Future<void> _resolveInitialLocation() async {
    final plannedLocation = await _targetPlanner.resolveAnimeLocation(
      anime: _anime,
      downloadRoot: defaultAnimeDownloadsRootDirectory().path,
    );
    state = state.copyWith(
      downloadFolder: state.downloadFolderSelectedByUser
          ? state.downloadFolder
          : plannedLocation.episodeDirectory,
      resolvedDownloadTitle: plannedLocation.httpJobTitle,
    );
  }

  Future<void> _resolveSources() async {
    final matches = await _sourceResolver.resolveAll(_anime);
    final preferredSource = _sourceResolver.selectPreferredSource(
      matches: matches,
      sourceSelectedByUser: state.sourceSelectedByUser,
      selectedSource: state.selectedSource,
    );
    final shouldPreserveUserSelection =
        state.sourceSelectedByUser &&
        state.selectedSource != null &&
        _sourceResolver.isSourceAvailable(matches, state.selectedSource!);
    state = state.copyWith(
      animepaheMatch: matches.animepaheMatch,
      tokyoinsiderMatch: matches.tokyoinsiderMatch,
      nyaaMatch: matches.nyaaMatch,
      selectedSource: preferredSource,
      sourceSelectedByUser: shouldPreserveUserSelection,
      clearSource: preferredSource == null,
    );
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

  void setStartEpisode(int episode) {
    state = state.copyWith(startEpisode: episode);
  }

  void setEndEpisode(int episode) {
    state = state.copyWith(endEpisode: episode, endEpisodeUsesLatest: false);
  }

  void useLatestEndEpisode() {
    state = state.copyWith(
      endEpisode: state.totalEpisodes,
      endEpisodeUsesLatest: true,
    );
  }

  void setDownloadFolder(String folder) {
    state = state.copyWith(
      downloadFolder: folder,
      downloadFolderSelectedByUser: true,
    );
  }

  void setTrackingEnabled(bool enabled) {
    state = state.copyWith(trackingEnabled: enabled);
  }

  void setSubmissionStage(DownloadSubmissionStage stage) {
    state = state.copyWith(submissionStage: stage);
  }

  void resetSubmissionStage() {
    state = state.copyWith(submissionStage: DownloadSubmissionStage.idle);
  }

  Future<PreparedDownloadBatch> prepareDownloads({
    required String startInput,
    required String endInput,
  }) async {
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

    final range = _parseEpisodeRange(
      startInput: startInput,
      endInput: endInput,
    );
    state = state.copyWith(
      startEpisode: range.start,
      endEpisode: range.end,
      endEpisodeUsesLatest: endInput.trim().isEmpty,
    );
    return _coordinator.plan(
      request: DownloadRequest(
        anime: state.anime,
        source: source,
        startEpisode: range.start,
        endEpisode: range.end,
        downloadFolder: folder,
        httpJobTitle: state.resolvedDownloadTitle,
        resolution: state.selectedResolution,
        language: state.selectedLanguage,
      ),
      animepaheMatch: state.animepaheMatch.result?.result,
      tokyoinsiderMatch: state.tokyoinsiderMatch.result?.result,
    );
  }

  Future<EnqueuedDownloadsResult> enqueuePreparedDownloads(
    PreparedDownloadBatch batch,
  ) async {
    return ref
        .read(DownloadManagerNotifier.provider.notifier)
        .enqueueBatch(batch);
  }

  ({int start, int end}) _parseEpisodeRange({
    required String startInput,
    required String endInput,
  }) {
    final totalEpisodes = state.totalEpisodes;
    final startText = startInput.trim();
    final endText = endInput.trim();
    final start = startText.isEmpty ? 1 : int.tryParse(startText);
    final end = endText.isEmpty ? totalEpisodes : int.tryParse(endText);

    if (start == null || end == null) {
      throw const DownloadUserError(
        title: 'Enter valid episode numbers',
        description: 'The episode range must contain valid integers.',
      );
    }
    if (start == 0 || end == 0) {
      throw const DownloadUserError(
        title: 'What am I supposed to do with a zero?',
        description: 'Episode numbers start at 1.',
      );
    }
    if (start < 0 || end < 0) {
      throw const DownloadUserError(
        title: 'Episode numbers must be positive',
        description: 'Negative episode numbers are not valid.',
      );
    }
    if (totalEpisodes > 0 && start > totalEpisodes) {
      throw DownloadUserError(
        title:
            'Start episode cannot be greater than the number of episodes the anime has',
        description:
            'Pick a start episode between 1 and $totalEpisodes for this anime.',
      );
    }
    if (end < start) {
      throw const DownloadUserError(
        title:
            'Stop episode cannot be less than start episode, hontoni baka ga',
        description: 'Choose an ending episode that is after the starting one.',
      );
    }
    if (totalEpisodes > 0 && end > totalEpisodes) {
      throw DownloadUserError(
        title:
            'Stop episode cannot be greater than the number of episodes this anime has',
        description:
            'Pick an ending episode between $start and $totalEpisodes for this anime.',
      );
    }
    return (start: start, end: end);
  }
}
