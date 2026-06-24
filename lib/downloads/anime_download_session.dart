import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/manager.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/nyaa_recovery.dart';
import 'package:senpwai/downloads/request_coordinator.dart';
import 'package:senpwai/downloads/source_resolver.dart';
import 'package:senpwai/downloads/target_path_planner.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/platform_paths.dart';
import 'package:senpwai/sources/shared/shared.dart';

enum DownloadSubmissionStage { idle, planning, reviewing, queueing }

int _availableEpisodesForAnime(AnilistAnimeBase anime) {
  final nextEpisodeNumber = anime.episode;
  if (nextEpisodeNumber != null) {
    var airedEpisodes = nextEpisodeNumber - 1;
    if (airedEpisodes < 0) {
      airedEpisodes = 0;
    }
    final totalEpisodes = anime.episodes;
    if (totalEpisodes != null && airedEpisodes > totalEpisodes) {
      airedEpisodes = totalEpisodes;
    }
    return airedEpisodes;
  }
  if (anime.status == AnilistAiringStatus.notYetReleased) {
    return 0;
  }
  return anime.episodes ?? 1;
}

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

  int get availableEpisodes => _availableEpisodesForAnime(anime);

  bool get hasAvailableEpisodes => availableEpisodes > 0;

  bool get allSourcesResolved =>
      !animepaheMatch.isLoading &&
      !tokyoinsiderMatch.isLoading &&
      !nyaaMatch.isLoading;

  bool get isSubmittingDownload =>
      submissionStage != DownloadSubmissionStage.idle;

  String get submitButtonLabel => isSubmittingDownload
      ? submissionStage.label(hasSource: selectedSource != null)
      : !allSourcesResolved
      ? 'Loading sources...'
      : selectedSource == null
      ? 'No source available'
      : hasAvailableEpisodes
      ? 'Download'
      : 'No aired episodes yet';

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
  final DownloadSourceResolver? _sourceResolverOverride;
  final AnimeDownloadCoordinator _coordinator;
  final DownloadTargetPlanner _targetPlanner;

  AnimeDownloadSessionNotifier._(
    this._anime, {
    DownloadSourceResolver? sourceResolver,
    AnimeDownloadCoordinator? coordinator,
    DownloadTargetPlanner? targetPlanner,
  }) : _sourceResolverOverride = sourceResolver,
       _coordinator = coordinator ?? AnimeDownloadCoordinator(),
       _targetPlanner = targetPlanner ?? const DownloadTargetPlanner();

  @override
  AnimeDownloadSessionState build() {
    final settings = ref.read(AppSettingsNotifier.provider);
    Future.microtask(_initialize);
    return AnimeDownloadSessionState(
      anime: _anime,
      selectedResolution: settings.content.defaultResolution,
      selectedLanguage: settings.content.defaultAudioLanguage,
      startEpisode: 1,
      endEpisode: _defaultAvailableEpisode,
      endEpisodeUsesLatest: true,
    );
  }

  AnimeDownloadSessionState get currentState => state;

  int get _defaultAvailableEpisode {
    final availableEpisodes = _availableEpisodesForAnime(_anime);
    return availableEpisodes > 0 ? availableEpisodes : 1;
  }

  Future<void> _initialize() async {
    await Future.wait([_resolveInitialLocation(), _resolveSources()]);
  }

  Future<void> _resolveInitialLocation() async {
    final settings = ref.read(AppSettingsNotifier.provider);
    final defaultRoot =
        settings.downloads.defaultRootDirectory ??
        (await defaultAnimeDownloadsRootDirectory()).path;
    final plannedLocation = await _targetPlanner.resolveAnimeLocation(
      anime: _anime,
      downloadRoot: defaultRoot,
    );
    state = state.copyWith(
      downloadFolder: state.downloadFolderSelectedByUser
          ? state.downloadFolder
          : plannedLocation.episodeDirectory,
      resolvedDownloadTitle: plannedLocation.httpJobTitle,
    );
  }

  Future<void> _resolveSources() async {
    final sourceResolver =
        _sourceResolverOverride ??
        DownloadSourceResolver(
          settings: ref.read(AppSettingsNotifier.provider).sources,
        );
    final matches = await sourceResolver.resolveAll(_anime);
    final preferredSource = sourceResolver.selectPreferredSource(
      matches: matches,
      sourceSelectedByUser: state.sourceSelectedByUser,
      selectedSource: state.selectedSource,
    );
    final shouldPreserveUserSelection =
        state.sourceSelectedByUser &&
        state.selectedSource != null &&
        sourceResolver.isSourceAvailable(matches, state.selectedSource!);
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
      endEpisode: state.hasAvailableEpisodes ? state.availableEpisodes : 1,
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

  Future<List<NyaaManualSearchCandidate>> searchNyaaManualCandidates({
    required int episodeNumber,
    required String query,
    NyaaManualSearchFilters filters = const NyaaManualSearchFilters(),
  }) async {
    return _coordinator.searchNyaaManualCandidates(
      request: _buildNyaaDownloadRequest(),
      episodeNumber: episodeNumber,
      query: query,
      filters: filters,
    );
  }

  Future<PreparedTorrentDownloadJob> planManualNyaaEpisode({
    required int episodeNumber,
    required NyaaManualSearchCandidate candidate,
  }) async {
    return _coordinator.planManualNyaaEpisode(
      request: _buildNyaaDownloadRequest(),
      episodeNumber: episodeNumber,
      candidate: candidate,
    );
  }

  DownloadRequest _buildNyaaDownloadRequest() {
    final folder = state.downloadFolder;
    if (folder == null || folder.trim().isEmpty) {
      throw const DownloadUserError(
        title: 'No folder selected',
        description: 'Choose a download folder before continuing.',
      );
    }
    return DownloadRequest(
      anime: state.anime,
      source: AnimeSource.nyaa,
      startEpisode: state.startEpisode,
      endEpisode: state.endEpisode,
      downloadFolder: folder,
      httpJobTitle: state.resolvedDownloadTitle,
      resolution: state.selectedResolution,
      language: state.selectedLanguage,
    );
  }

  ({int start, int end}) _parseEpisodeRange({
    required String startInput,
    required String endInput,
  }) {
    final availableEpisodes = state.availableEpisodes;
    if (availableEpisodes <= 0) {
      throw const DownloadUserError(
        title: 'No aired episodes yet',
        description:
            'This anime does not have any released episodes available to download yet.',
      );
    }
    final startText = startInput.trim();
    final endText = endInput.trim();
    final start = startText.isEmpty ? 1 : int.tryParse(startText);
    final end = endText.isEmpty ? availableEpisodes : int.tryParse(endText);

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
    if (start > availableEpisodes) {
      throw DownloadUserError(
        title: 'Start episode cannot be greater than the latest aired episode',
        description:
            'Pick a start episode between 1 and $availableEpisodes for this anime.',
      );
    }
    if (end < start) {
      throw const DownloadUserError(
        title:
            'Stop episode cannot be less than start episode, hontoni baka ga',
        description: 'Choose an ending episode that is after the starting one.',
      );
    }
    if (end > availableEpisodes) {
      throw DownloadUserError(
        title: 'Stop episode cannot be greater than the latest aired episode',
        description:
            'Pick an ending episode between $start and $availableEpisodes for this anime.',
      );
    }
    return (start: start, end: end);
  }
}
