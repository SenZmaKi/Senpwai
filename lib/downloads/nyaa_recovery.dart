import 'package:senpwai/sources/nyaa.dart' as nyaa;
import 'package:senpwai/sources/shared/matcher/nyaa.dart';
import 'package:senpwai/sources/shared/shared.dart';

enum NyaaManualSearchSort { smart, seeders, newest, size }

extension NyaaManualSearchSortExtension on NyaaManualSearchSort {
  String get label => switch (this) {
    NyaaManualSearchSort.smart => 'Best match',
    NyaaManualSearchSort.seeders => 'Seeders',
    NyaaManualSearchSort.newest => 'Newest',
    NyaaManualSearchSort.size => 'Size',
  };
}

extension NyaaLanguageSignalExtension on NyaaLanguageSignal {
  String get label => switch (this) {
    NyaaLanguageSignal.dualAudio => 'Dual audio',
    NyaaLanguageSignal.dubbed => 'Dubbed',
    NyaaLanguageSignal.subbed => 'Subbed',
    NyaaLanguageSignal.unknown => 'Unknown audio',
  };
}

enum NyaaBatchMode { any, batchOnly, singleOnly }

extension NyaaBatchModeExtension on NyaaBatchMode {
  String get label => switch (this) {
    NyaaBatchMode.any => 'Any',
    NyaaBatchMode.batchOnly => 'Batches only',
    NyaaBatchMode.singleOnly => 'Single episodes only',
  };
}

class NyaaManualSearchFilters {
  // Server-side filters (passed into search API).
  final bool exactEpisodeOnly;
  final bool sameSeasonOnly;
  final bool preferredLanguageOnly;
  final NyaaManualSearchSort sort;

  // Frontend-only filters (applied after results return).
  final Set<Resolution> resolutions;
  final Set<NyaaLanguageSignal> languageSignals;
  final NyaaBatchMode batchMode;
  final int minSeeders;
  final int? minSizeBytes;
  final int? maxSizeBytes;

  const NyaaManualSearchFilters({
    this.exactEpisodeOnly = true,
    this.sameSeasonOnly = true,
    this.preferredLanguageOnly = true,
    this.sort = NyaaManualSearchSort.smart,
    this.resolutions = const {},
    this.languageSignals = const {},
    this.batchMode = NyaaBatchMode.any,
    this.minSeeders = 0,
    this.minSizeBytes,
    this.maxSizeBytes,
  });

  NyaaManualSearchFilters copyWith({
    bool? exactEpisodeOnly,
    bool? sameSeasonOnly,
    bool? preferredLanguageOnly,
    NyaaManualSearchSort? sort,
    Set<Resolution>? resolutions,
    Set<NyaaLanguageSignal>? languageSignals,
    NyaaBatchMode? batchMode,
    int? minSeeders,
    int? minSizeBytes,
    int? maxSizeBytes,
    bool clearMinSize = false,
    bool clearMaxSize = false,
  }) {
    return NyaaManualSearchFilters(
      exactEpisodeOnly: exactEpisodeOnly ?? this.exactEpisodeOnly,
      sameSeasonOnly: sameSeasonOnly ?? this.sameSeasonOnly,
      preferredLanguageOnly:
          preferredLanguageOnly ?? this.preferredLanguageOnly,
      sort: sort ?? this.sort,
      resolutions: resolutions ?? this.resolutions,
      languageSignals: languageSignals ?? this.languageSignals,
      batchMode: batchMode ?? this.batchMode,
      minSeeders: minSeeders ?? this.minSeeders,
      minSizeBytes: clearMinSize ? null : (minSizeBytes ?? this.minSizeBytes),
      maxSizeBytes: clearMaxSize ? null : (maxSizeBytes ?? this.maxSizeBytes),
    );
  }

  /// Number of filters that diverge from the inert default state.
  /// Sort is excluded — it's not a filter, it's an ordering.
  int get activeCount {
    var n = 0;
    if (!exactEpisodeOnly) n++;
    if (!sameSeasonOnly) n++;
    if (!preferredLanguageOnly) n++;
    if (resolutions.isNotEmpty) n++;
    if (languageSignals.isNotEmpty) n++;
    if (batchMode != NyaaBatchMode.any) n++;
    if (minSeeders > 0) n++;
    if (minSizeBytes != null || maxSizeBytes != null) n++;
    return n;
  }

  /// Apply client-side filters to a candidate list. Server-side filters
  /// (exactEpisode, sameSeason, preferredLanguage) are assumed to have
  /// already been applied during the search call.
  List<NyaaManualSearchCandidate> applyClientSide(
    Iterable<NyaaManualSearchCandidate> input,
  ) {
    return input.where((c) {
      if (resolutions.isNotEmpty) {
        if (c.resolution == null || !resolutions.contains(c.resolution)) {
          return false;
        }
      }
      if (languageSignals.isNotEmpty &&
          !languageSignals.contains(c.languageSignal)) {
        return false;
      }
      switch (batchMode) {
        case NyaaBatchMode.batchOnly:
          if (!c.isBatch) return false;
          break;
        case NyaaBatchMode.singleOnly:
          if (c.isBatch) return false;
          break;
        case NyaaBatchMode.any:
          break;
      }
      if (c.result.seeders < minSeeders) return false;
      final size = c.result.sizeBytes;
      if (minSizeBytes != null && size < minSizeBytes!) return false;
      if (maxSizeBytes != null && size > maxSizeBytes!) return false;
      return true;
    }).toList();
  }
}

class NyaaSearchConfiguration {
  final String query;
  final NyaaManualSearchFilters filters;

  const NyaaSearchConfiguration({
    required this.query,
    this.filters = const NyaaManualSearchFilters(),
  });
}

class NyaaEpisodeResolutionIssue {
  final int episodeNumber;
  final String title;
  final String description;
  final NyaaSearchConfiguration searchConfiguration;

  const NyaaEpisodeResolutionIssue({
    required this.episodeNumber,
    required this.title,
    required this.description,
    required this.searchConfiguration,
  });

  String get initialQuery => searchConfiguration.query;
}

class NyaaManualSearchCandidate {
  final nyaa.AnimeResult result;
  final int? parsedEpisodeNumber;
  final int? parsedSeasonNumber;
  final Resolution? resolution;
  final NyaaLanguageSignal languageSignal;
  final double titleScore;
  final bool matchesRequestedEpisode;
  final bool matchesRequestedSeason;
  final bool matchesPreferredLanguage;
  final bool isBatch;
  final double smartScore;
  final String searchQuery;

  const NyaaManualSearchCandidate({
    required this.result,
    required this.parsedEpisodeNumber,
    required this.parsedSeasonNumber,
    required this.resolution,
    required this.languageSignal,
    required this.titleScore,
    required this.matchesRequestedEpisode,
    required this.matchesRequestedSeason,
    required this.matchesPreferredLanguage,
    required this.isBatch,
    required this.smartScore,
    required this.searchQuery,
  });
}
