import 'package:collection/collection.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

enum Language {
  japanese,
  english;

  @override
  String toString() => switch (this) {
    Language.japanese => "Japanese",
    Language.english => "English",
  };
}

enum Resolution {
  res4320p(4320), // 8K
  res2160p(2160), // 4K
  res1440p(1440), // 2K
  res1080p(1080),
  res720p(720),
  res480p(480),
  res360p(360),
  res240p(240),
  res144p(144);

  final int value;

  const Resolution(this.value);

  static Resolution? fromInt(int height) =>
      Resolution.values.firstWhereOrNull((res) => res.value == height);

  static Resolution? fromString(String height) {
    final intValue = int.tryParse(height);
    if (intValue == null) return null;
    return fromInt(intValue);
  }

  @override
  String toString() => "${value}p";
}

Document parseHtml(dynamic input) {
  return html.parse(input);
}

Resolution? parseResolution(String text) {
  final match = Constants.resolutionRegex.firstMatch(text);
  final height = match?.group(1) ?? match?.group(2);
  if (height == null) return null;
  final resolution = Resolution.fromString(height);
  return resolution;
}

class Constants {
  static final resolutionRegex = RegExp(r'\b(?:(\d{3,4})p|\d+x(\d+))\b');

  /// Minimum fuzzy title similarity score (0–100) for a source result to be
  /// considered a valid match against an AniList title candidate.
  static const minMatchScore = 90;
}

class SourceException implements Exception {
  final String message;
  final Map<String, dynamic> metadata;
  SourceException({required this.message, required this.metadata});

  @override
  String toString() => 'ScrapingException: $message, metadata: $metadata';
}
