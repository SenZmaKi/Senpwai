import 'package:senpwai/sources/shared/fuzzy.dart';

class SourceMatch<T> {
  final T result;
  final int score;
  final String matchedTitle;

  const SourceMatch({
    required this.result,
    required this.score,
    required this.matchedTitle,
  });

  @override
  String toString() =>
      "SourceMatch(result: $result, score: $score, matchedTitle: $matchedTitle)";
}

/// Score a result against all AniList title candidates, returning the best
/// fuzzy title similarity.
int bestTitleScore(List<String> titleCandidates, String resultTitle) {
  return titleCandidates
      .map((candidate) => titleSimilarity(candidate, resultTitle))
      .reduce((a, b) => a > b ? a : b);
}

/// Sort matches by score descending, with a tiebreaker: when scores are equal,
/// prefer the result whose title is closest in length to the shortest AniList
/// title candidate (more exact match over subset match).
void sortMatches<T>(
  List<SourceMatch<T>> matches,
  List<String> titleCandidates,
  String Function(T result) getTitle,
) {
  final refLength =
      titleCandidates.map((t) => t.length).reduce((a, b) => a < b ? a : b);
  matches.sort((a, b) {
    final cmp = b.score.compareTo(a.score);
    if (cmp != 0) return cmp;
    final aDiff = (getTitle(a.result).length - refLength).abs();
    final bDiff = (getTitle(b.result).length - refLength).abs();
    return aDiff.compareTo(bDiff);
  });
}
