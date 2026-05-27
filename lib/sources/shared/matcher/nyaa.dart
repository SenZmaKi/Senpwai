import 'dart:math' as math;

import 'package:logging/logging.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/anitomy/anitomy.dart' as anitomy_parser;
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/sources/nyaa.dart' as nyaa;
import 'package:senpwai/sources/shared/fuzzy.dart';
import 'package:senpwai/sources/shared/shared.dart';

final _log = Logger("senpwai.sources.nyaa.matcher");

// ─── Data classes ────────────────────────────────────────────────────────────

/// Configuration shared across all NyaaMatcher public methods.
class NyaaMatchParams {
  final Resolution preferredResolution;
  final Language preferredLanguage;

  const NyaaMatchParams({
    required this.preferredResolution,
    required this.preferredLanguage,
  });
}

class ScoredNyaaResult {
  final double score;
  final Resolution resolution;
  final nyaa.AnimeResult result;
  final bool isCompleteSeason;

  const ScoredNyaaResult({
    required this.result,
    required this.score,
    required this.resolution,
    required this.isCompleteSeason,
  });

  @override
  String toString() =>
      'ScoredNyaaResult(filename: ${result.filename}, score: $score, '
      'resolution: $resolution, isCompleteSeason: $isCompleteSeason)';
}

class NyaaEpisodeMatch {
  final int episodeNumber;

  /// Sorted by score descending.
  final List<ScoredNyaaResult> matches;

  const NyaaEpisodeMatch({required this.episodeNumber, required this.matches});

  @override
  String toString() =>
      'NyaaEpisodeMatch(episodeNumber: $episodeNumber, matchCount: ${matches.length})';
}

// ─── Search term helpers ─────────────────────────────────────────────────────

/// Splits a title into its base name and optional season number by delegating
/// to anitomy, which already knows how to extract season info from strings
/// like "Jujutsu Kaisen Season 2" or "Attack on Titan S3".
({String baseTitle, int? seasonNumber}) _parseSeasonFromTitle(String title) {
  final parsed = anitomy_parser.parseFilename(title);
  return (baseTitle: parsed.title ?? title, seasonNumber: parsed.season);
}

String _pad(int n) => n.toString().padLeft(2, '0');

final _segmentSuffixPattern = RegExp(
  r'(?:\s*[-:]\s*|\s+)(?:(?:part|pt|cour)\s*(\d{1,3})|(\d{1,3})(?:st|nd|rd|th)\s*(?:part|cour))$',
  caseSensitive: false,
);

String stripNyaaSegmentMarker(String title) {
  final trimmed = title.trim();
  return trimmed.replaceFirst(_segmentSuffixPattern, '').trim();
}

List<String> expandNyaaTitleCandidates(Iterable<String> titleCandidates) {
  final variants = <String>[];

  void add(String candidate) {
    final trimmed = candidate.trim();
    if (trimmed.isEmpty || variants.contains(trimmed)) return;
    variants.add(trimmed);
  }

  for (final candidate in titleCandidates) {
    add(candidate);
    final parsed = _parseSeasonFromTitle(candidate);
    add(parsed.baseTitle);
    final stripped = stripNyaaSegmentMarker(candidate);
    add(stripped);
    add(_parseSeasonFromTitle(stripped).baseTitle);
  }
  return variants;
}

bool matchesPreferredNyaaLanguage(
  anitomy_parser.AnitomyParseResult parsed,
  Language preferredLanguage,
) {
  final signal = classifyNyaaLanguageSignal(parsed);
  if (signal == NyaaLanguageSignal.dualAudio) {
    return true;
  }
  return switch (preferredLanguage) {
    Language.japanese => signal != NyaaLanguageSignal.dubbed,
    Language.english => signal != NyaaLanguageSignal.subbed,
  };
}

enum NyaaLanguageSignal { dubbed, subbed, dualAudio, unknown }

String _normalizeNyaaMarker(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

NyaaLanguageSignal classifyNyaaLanguageSignal(
  anitomy_parser.AnitomyParseResult parsed,
) {
  final normalizedAudioTerms = parsed.audioTerms.map(_normalizeNyaaMarker);
  if (normalizedAudioTerms.any((value) => value.contains('dualaudio'))) {
    return NyaaLanguageSignal.dualAudio;
  }

  final normalizedSubtitles = parsed.subtitles.map(_normalizeNyaaMarker);
  if (normalizedSubtitles.any((value) => value.contains('dub'))) {
    return NyaaLanguageSignal.dubbed;
  }
  if (normalizedSubtitles.any((value) => value.contains('sub'))) {
    return NyaaLanguageSignal.subbed;
  }

  return NyaaLanguageSignal.unknown;
}

/// Returns the nyaa search terms to use when looking for a complete season/batch pack.
///
/// For each title candidate generates both `S02 complete` and `Season 2 complete`
/// variants so searches run concurrently against each.
List<String> _seasonSearchTerms(String title) {
  final (:baseTitle, :seasonNumber) = _parseSeasonFromTitle(title);
  if (seasonNumber == null) return ['$title complete'];
  return [
    '$baseTitle S${_pad(seasonNumber)} complete',
    '$baseTitle Season $seasonNumber complete',
  ];
}

/// Returns the nyaa search terms to use when looking for a movie.
///
/// Movies are uploaded as the film itself with no "complete" suffix, so the
/// bare title is used.
List<String> _movieSearchTerms(String title) => [title];

/// Returns the nyaa search terms to use when looking for a specific episode.
///
/// Uses bare `$title $paddedEp` (e.g. "Boku no Hero Academia 01") because
/// most Nyaa uploads follow the `[Group] Title - 01 [resolution].ext` pattern
/// where the episode number is a standalone token. Explicit labels like
/// "E01" or "Episode 1" are not commonly used in torrent filenames and return
/// empty results.
List<String> _episodeSearchTerms(String title, int episodeNumber) {
  final (:baseTitle, :seasonNumber) = _parseSeasonFromTitle(title);
  final paddedEp = _pad(episodeNumber);
  if (seasonNumber == null) {
    return ['$title $paddedEp'];
  }
  return [
    '$baseTitle S${_pad(seasonNumber)}E$paddedEp',
    '$baseTitle S${_pad(seasonNumber)} $paddedEp',
  ];
}

// ─── Validation ──────────────────────────────────────────────────────────────

typedef _Candidate = ({
  nyaa.AnimeResult result,
  Resolution resolution,
  bool isCompleteSeason,
});

/// Returns [resolution] + [isCompleteSeason] when the parsed filename is a
/// valid match, or `null` when it should be discarded.
({Resolution resolution, bool isCompleteSeason})? _validateParsed({
  required anitomy_parser.AnitomyParseResult parsed,
  required List<String> titleCandidates,
  required Language preferredLanguage,
  required bool wantComplete,
}) {
  if (parsed.resolution == null || parsed.title == null) return null;

  if (!matchesPreferredNyaaLanguage(parsed, preferredLanguage)) {
    return null;
  }

  final allCandidates = expandNyaaTitleCandidates(titleCandidates);

  final bestScore = allCandidates
      .map((c) => titleSimilarity(c, parsed.title!))
      .reduce((a, b) => a > b ? a : b);
  if (bestScore < Constants.minMatchScore) return null;

  final isCompleteSeason = parsed.episode == null;
  if (wantComplete != isCompleteSeason) return null;

  return (resolution: parsed.resolution!, isCompleteSeason: isCompleteSeason);
}

// ─── Scoring ─────────────────────────────────────────────────────────────────

/// Scores and sorts [candidates] using a weighted metric:
/// - Seeders  (weight 0.375): rewards popularity.
/// - Resolution closeness (weight 0.3): rewards proximity to [preferredResolution].
/// - Size penalty (weight 0.325): penalises large files, partially pardoned for
///   high-resolution content (higher-res files are legitimately larger).
List<ScoredNyaaResult> _scoreAndSort({
  required List<_Candidate> candidates,
  required Resolution preferredResolution,
  double seedersWeight = 0.375,
  double resolutionWeight = 0.3,
  double sizeWeight = 0.325,
  double resolutionPardonFactor = 0.6,
}) {
  if (candidates.isEmpty) return [];

  final allResValues = Resolution.values
      .map((r) => r.value.toDouble())
      .toList();
  final minRes = allResValues.reduce(math.min);
  final maxRes = allResValues.reduce(math.max);
  final maxResolutionDifference = maxRes - minRes;

  final maxSeedersRaw = candidates
      .map((c) => c.result.seeders)
      .reduce(math.max);
  final maxSeedersThreshold = math.min(100, maxSeedersRaw).toDouble();

  final maxSizeThreshold = candidates
      .map((c) => c.result.sizeBytes)
      .reduce(math.max)
      .toDouble();

  return candidates.map((c) {
    final resDiff =
        (c.resolution.value.toDouble() - preferredResolution.value.toDouble())
            .abs();
    final resolutionScore = maxResolutionDifference > 0
        ? 1.0 - resDiff / maxResolutionDifference
        : 1.0;

    final seedersScore = maxSeedersThreshold > 0
        ? math.min(c.result.seeders / maxSeedersThreshold, 1.0)
        : 0.0;

    final sizePenalty = maxSizeThreshold > 0
        ? math.min(c.result.sizeBytes / maxSizeThreshold, 1.0)
        : 0.0;
    final resolutionPardon = maxResolutionDifference > 0
        ? (c.resolution.value.toDouble() - minRes) / maxResolutionDifference
        : 0.0;
    final pardonedSizePenalty =
        sizePenalty - resolutionPardon * resolutionPardonFactor;

    final score =
        -pardonedSizePenalty * sizeWeight +
        resolutionScore * resolutionWeight +
        seedersScore * seedersWeight;

    return ScoredNyaaResult(
      result: c.result,
      score: score,
      resolution: c.resolution,
      isCompleteSeason: c.isCompleteSeason,
    );
  }).toList()..sort((a, b) => b.score.compareTo(a.score));
}

// ─── Matcher ─────────────────────────────────────────────────────────────────

class NyaaMatcher {
  final nyaa.Source _source;

  NyaaMatcher({nyaa.Source? source})
    : _source = source ?? nyaa.Source.getInstance();

  Future<List<nyaa.AnimeResult>> _search(String term, int anilistId) async {
    _log.infoWithMetadata(
      "Nyaa search",
      metadata: {"term": term, "anilistId": anilistId},
    );
    try {
      final pagination = await _source.search(
        params: nyaa.SearchParams(term: term, page: 1),
      );
      return pagination.items;
    } catch (e) {
      _log.warningWithMetadata(
        "Nyaa search failed",
        metadata: {"term": term, "error": e.toString()},
      );
      return [];
    }
  }

  /// Collects and validates all [searchTerms] results into scored candidates.
  ///
  /// Shared by [matchSeason] and [matchMovie]; both look for torrents with no
  /// episode number (`wantComplete: true`) and differ only in their search terms.
  Future<List<ScoredNyaaResult>> _fetchAndScore({
    required List<String> searchTerms,
    required int anilistId,
    required List<String> titleCandidates,
    required NyaaMatchParams params,
  }) async {
    final seenUrls = <String>{};
    final candidates = <_Candidate>[];

    for (final results in await Future.wait(
      searchTerms.map((term) => _search(term, anilistId)),
    )) {
      for (final result in results) {
        if (!seenUrls.add(result.magnetUrl)) continue;
        if (result.seeders == 0) continue;
        final parsed = anitomy_parser.parseFilename(result.filename);
        final validated = _validateParsed(
          parsed: parsed,
          titleCandidates: titleCandidates,
          preferredLanguage: params.preferredLanguage,
          wantComplete: true,
        );
        if (validated == null) continue;
        candidates.add((
          result: result,
          resolution: validated.resolution,
          isCompleteSeason: validated.isCompleteSeason,
        ));
      }
    }

    return _scoreAndSort(
      candidates: candidates,
      preferredResolution: params.preferredResolution,
    );
  }

  /// Searches Nyaa for a complete season/batch pack of [anime].
  ///
  /// For each title candidate generates both `S02 complete` and
  /// `Season 2 complete` queries and runs all of them concurrently.
  Future<List<ScoredNyaaResult>> matchSeason(
    AnilistAnimeBase<dynamic> anime,
    NyaaMatchParams params,
  ) async {
    final titleCandidates = anime.title.toTitleCandidates();
    if (titleCandidates.isEmpty) return [];
    final expandedTitleCandidates = expandNyaaTitleCandidates(titleCandidates);

    final scored = await _fetchAndScore(
      searchTerms: expandedTitleCandidates.expand(_seasonSearchTerms).toList(),
      anilistId: anime.id,
      titleCandidates: titleCandidates,
      params: params,
    );
    _log.fineWithMetadata(
      "Nyaa season matching done",
      metadata: {
        "anilistId": anime.id,
        "matchCount": scored.length,
        "topScore": scored.isNotEmpty ? scored.first.score : null,
      },
    );
    return scored;
  }

  /// Searches Nyaa for a movie torrent of [anime].
  ///
  /// Uses the bare title without a "complete" suffix since movie uploads are
  /// the film itself and don't include that keyword.
  Future<List<ScoredNyaaResult>> matchMovie(
    AnilistAnimeBase<dynamic> anime,
    NyaaMatchParams params,
  ) async {
    final titleCandidates = anime.title.toTitleCandidates();
    if (titleCandidates.isEmpty) return [];
    final expandedTitleCandidates = expandNyaaTitleCandidates(titleCandidates);

    final scored = await _fetchAndScore(
      searchTerms: expandedTitleCandidates.expand(_movieSearchTerms).toList(),
      anilistId: anime.id,
      titleCandidates: titleCandidates,
      params: params,
    );
    _log.fineWithMetadata(
      "Nyaa movie matching done",
      metadata: {
        "anilistId": anime.id,
        "matchCount": scored.length,
        "topScore": scored.isNotEmpty ? scored.first.score : null,
      },
    );
    return scored;
  }

  /// Searches Nyaa for individual episodes of [anime].
  ///
  /// For each requested episode number generates `S02 E01` and
  /// `Season 2 Episode 1` queries across all title candidates and fetches all
  /// of them concurrently. Episode groups themselves are also fetched in
  /// parallel.
  Future<List<NyaaEpisodeMatch>> matchEpisodes(
    AnilistAnimeBase<dynamic> anime,
    NyaaMatchParams params, {
    required List<int> episodeNumbers,
  }) async {
    if (episodeNumbers.isEmpty) return [];
    final titleCandidates = anime.title.toTitleCandidates();
    if (titleCandidates.isEmpty) return [];
    final expandedTitleCandidates = expandNyaaTitleCandidates(titleCandidates);

    Future<NyaaEpisodeMatch> fetchEpisode(int epNum) async {
      final searchTerms = expandedTitleCandidates
          .expand((t) => _episodeSearchTerms(t, epNum))
          .toList();

      final seenUrls = <String>{};
      final candidates = <_Candidate>[];

      for (final results in await Future.wait(
        searchTerms.map((term) => _search(term, anime.id)),
      )) {
        for (final result in results) {
          if (!seenUrls.add(result.magnetUrl)) continue;
          if (result.seeders == 0) continue;
          final parsed = anitomy_parser.parseFilename(result.filename);
          final validated = _validateParsed(
            parsed: parsed,
            titleCandidates: titleCandidates,
            preferredLanguage: params.preferredLanguage,
            wantComplete: false,
          );
          if (validated == null) continue;
          if (parsed.episode != epNum) continue;
          candidates.add((
            result: result,
            resolution: validated.resolution,
            isCompleteSeason: validated.isCompleteSeason,
          ));
        }
      }

      return NyaaEpisodeMatch(
        episodeNumber: epNum,
        matches: _scoreAndSort(
          candidates: candidates,
          preferredResolution: params.preferredResolution,
        ),
      );
    }

    final matches = await Future.wait(episodeNumbers.map(fetchEpisode));

    _log.fineWithMetadata(
      "Nyaa episode matching done",
      metadata: {
        "anilistId": anime.id,
        "episodesRequested": episodeNumbers.length,
        "episodesMatched": matches.where((m) => m.matches.isNotEmpty).length,
      },
    );
    return matches;
  }
}
