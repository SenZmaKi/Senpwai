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

class NyaaManualSearchFilters {
  final bool exactEpisodeOnly;
  final bool sameSeasonOnly;
  final bool preferredLanguageOnly;
  final NyaaManualSearchSort sort;

  const NyaaManualSearchFilters({
    this.exactEpisodeOnly = true,
    this.sameSeasonOnly = true,
    this.preferredLanguageOnly = true,
    this.sort = NyaaManualSearchSort.smart,
  });

  NyaaManualSearchFilters copyWith({
    bool? exactEpisodeOnly,
    bool? sameSeasonOnly,
    bool? preferredLanguageOnly,
    NyaaManualSearchSort? sort,
  }) {
    return NyaaManualSearchFilters(
      exactEpisodeOnly: exactEpisodeOnly ?? this.exactEpisodeOnly,
      sameSeasonOnly: sameSeasonOnly ?? this.sameSeasonOnly,
      preferredLanguageOnly:
          preferredLanguageOnly ?? this.preferredLanguageOnly,
      sort: sort ?? this.sort,
    );
  }
}

class NyaaEpisodeResolutionIssue {
  final int episodeNumber;
  final String title;
  final String description;
  final String initialQuery;

  const NyaaEpisodeResolutionIssue({
    required this.episodeNumber,
    required this.title,
    required this.description,
    required this.initialQuery,
  });
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
  });
}
