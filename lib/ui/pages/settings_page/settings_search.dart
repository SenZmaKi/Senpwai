import 'package:fuzzywuzzy/fuzzywuzzy.dart';

final _punctuation = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
final _whitespace = RegExp(r'\s+');

String _normalize(String value) => value
    .replaceAll(_punctuation, ' ')
    .replaceAll(_whitespace, ' ')
    .trim()
    .toLowerCase();

bool settingsSearchMatches(String? query, Iterable<String> terms) {
  if (query == null || query.trim().isEmpty) return true;

  final normalizedQuery = _normalize(query);
  final normalizedTerms = terms
      .map(_normalize)
      .where((term) => term.isNotEmpty)
      .toList();
  final haystack = normalizedTerms.join(' ');

  if (haystack.contains(normalizedQuery)) return true;

  final queryTokens = normalizedQuery.split(' ');
  final termTokens = haystack.split(' ');
  return queryTokens.every((queryToken) {
    if (queryToken.length < 4) return termTokens.contains(queryToken);
    final minimumScore = queryToken.length == 4 ? 75 : 80;
    return termTokens.any(
      (termToken) =>
          termToken.length >= 4 && ratio(queryToken, termToken) >= minimumScore,
    );
  });
}

abstract interface class SettingsSearchable {
  bool matchesSearch(String? query);
}
