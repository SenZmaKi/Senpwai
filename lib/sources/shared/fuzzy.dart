import 'dart:math' as math;
import 'package:fuzzywuzzy/fuzzywuzzy.dart';

final _nonAlphanumeric = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

/// Strips all non-alphanumeric characters (preserving Unicode letters/digits)
/// and collapses whitespace for cleaner fuzzy comparison.
String _normalize(String s) =>
    s.replaceAll(_nonAlphanumeric, ' ').replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

/// Computes a fuzzy title similarity score that avoids inflated partial matches.
/// Normalizes punctuation before comparing so `wa.` matches `wa` and `(TV)` is
/// ignored. Uses the max of simple ratio, token sort ratio, and token set ratio
/// — avoids `weightedRatio` which over-inflates scores for common particles.
int titleSimilarity(String candidate, String target) {
  final c = _normalize(candidate);
  final t = _normalize(target);
  final r = ratio(c, t);
  final tsr = tokenSortRatio(c, t);
  final tsetr = tokenSetRatio(c, t);
  return math.max(r, math.max(tsr, tsetr));
}
