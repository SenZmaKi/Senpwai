import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:anitomy_dart/anitomy.dart' as anitomy;

final _ani = anitomy.Anitomy();
Logger log = Logger("senpwai.anitomy.anitomy");

class AnitomyParseResult {
  int? season;
  int? episode;
  String? title;
  Language? language;
  Resolution? resolution;
  List<String> animeTypes;

  AnitomyParseResult({
    this.season,
    this.episode,
    this.title,
    this.language,
    this.resolution,
    this.animeTypes = const [],
  });

  @override
  String toString() =>
      "AnitomyParseResult(season: $season, episode: $episode, title: $title, language: $language, resolution: $resolution, animeTypes: $animeTypes)";
}

T? _parseCategory<T>({
  required List<anitomy.ElementPair> elements,
  required anitomy.ElementCategory category,
  required T? Function(String elementValue) parser,
}) {
  final element = elements.firstWhereOrNull(
    (element) => element.category == category,
  );
  log.infoWithMetadata(
    "Parsed category",
    metadata: {"element": element, "category": category},
  );
  if (element == null) return null;
  return parser(element.value);
}

List<T> _parseCategories<T>({
  required List<anitomy.ElementPair> elements,
  required anitomy.ElementCategory category,
  required T Function(String elementValue) parser,
}) {
  return [
    for (final element in elements.where(
      (element) => element.category == category,
    ))
      parser(element.value),
  ];
}

final _seasonSuffixPattern = RegExp(
  r'^第?\s*(\d{1,3})\s*(?:期|cour|クール)$',
  caseSensitive: false,
);

bool _looksLikeSeasonMarker(String elementValue) =>
    _seasonSuffixPattern.hasMatch(elementValue.trim());

int? _parseIntElement(
  String? elementValue, {
  required anitomy.ElementCategory category,
  bool allowSeasonMarkers = false,
}) {
  if (elementValue == null) return null;
  final trimmedValue = elementValue.trim();
  final directValue = int.tryParse(trimmedValue);
  if (directValue != null) return directValue;

  if (allowSeasonMarkers) {
    final seasonMatch = _seasonSuffixPattern.firstMatch(trimmedValue);
    final seasonValue = seasonMatch?.group(1);
    if (seasonValue != null) {
      return int.tryParse(seasonValue);
    }
  }

  log.warningWithMetadata(
    "Could not parse numeric anitomy element",
    metadata: {"category": category, "value": elementValue},
  );
  return null;
}

AnitomyParseResult parseFilename(String filename) {
  log.infoWithMetadata("Parsing filename", metadata: {"filename": filename});
  _ani.parse(filename);
  final elements = _ani.elements.items.toList();
  final rawSeason = _parseCategory(
    elements: elements,
    category: anitomy.ElementCategory.animeSeason,
    parser: (elementValue) => elementValue,
  );
  final rawEpisode = _parseCategory(
    elements: elements,
    category: anitomy.ElementCategory.episodeNumber,
    parser: (elementValue) => elementValue,
  );
  final season =
      _parseIntElement(
        rawSeason,
        category: anitomy.ElementCategory.animeSeason,
        allowSeasonMarkers: true,
      ) ??
      (_looksLikeSeasonMarker(rawEpisode ?? '')
          ? _parseIntElement(
              rawEpisode,
              category: anitomy.ElementCategory.episodeNumber,
              allowSeasonMarkers: true,
            )
          : null);
  final episode = _looksLikeSeasonMarker(rawEpisode ?? '')
      ? null
      : _parseIntElement(
          rawEpisode,
          category: anitomy.ElementCategory.episodeNumber,
        );
  final title = _parseCategory(
    elements: elements,
    category: anitomy.ElementCategory.animeTitle,
    parser: (elementValue) => elementValue,
  );
  final language = _parseCategory(
    elements: elements,
    category: anitomy.ElementCategory.language,
    parser: (elementValue) => switch (elementValue) {
      "ENGLISH" => Language.english,
      "JAPANESE" => Language.japanese,
      _ => null,
    },
  );
  final resolution = _parseCategory(
    elements: elements,
    category: anitomy.ElementCategory.videoResolution,
    parser: parseResolution,
  );
  final animeTypes = _parseCategories(
    elements: elements,
    category: anitomy.ElementCategory.animeType,
    parser: (elementValue) => elementValue,
  );

  final anitomyParseResult = AnitomyParseResult(
    season: season,
    episode: episode,
    title: title,
    language: language,
    resolution: resolution,
    animeTypes: animeTypes,
  );
  log.fineWithMetadata(
    "Parsed",
    metadata: {"filename": filename, "anitomyParseResult": anitomyParseResult},
  );
  return anitomyParseResult;
}
