import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'ffi.dart';

Logger log = Logger("senpwai.sources.shared.anitomy.anitomy");

AnitomyFFI _anitomyFFi = AnitomyFFI();

class AnitomyParseResult {
  int? season;
  int? episode;
  String? title;
  Language? language;
  Resolution? resolution;

  AnitomyParseResult({
    this.season,
    this.episode,
    this.title,
    this.language,
    this.resolution,
  });

  @override
  String toString() =>
      "AnitomyParseResult(season: $season, episode: $episode, title: $title, language: $language, resolution: $resolution)";
}

T? _parseCategory<T>({
  required List<AnitomyElement> elements,
  required ElementCategory category,
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

AnitomyParseResult parseFilename(String filename) {
  log.infoWithMetadata("Parsing filename", metadata: {"filename": filename});
  final parsed = _anitomyFFi.parse(filename);
  final season = _parseCategory(
    elements: parsed,
    category: ElementCategory.kElementAnimeSeason,
    parser: (elementValue) => int.parse(elementValue),
  );
  final episode = _parseCategory(
    elements: parsed,
    category: ElementCategory.kElementEpisodeNumber,
    parser: (elementValue) => int.parse(elementValue),
  );
  final title = _parseCategory(
    elements: parsed,
    category: ElementCategory.kElementAnimeTitle,
    parser: (elementValue) => elementValue,
  );
  final language = _parseCategory(
    elements: parsed,
    category: ElementCategory.kElementLanguage,
    parser: (elementValue) => switch (elementValue) {
      "ENGLISH" => Language.english,
      "JAPANESE" => Language.japanese,
      _ => null,
    },
  );
  final resolution = _parseCategory(
    elements: parsed,
    category: ElementCategory.kElementVideoResolution,
    parser: parseResolution,
  );

  final anitomyParseResult = AnitomyParseResult(
    season: season,
    episode: episode,
    title: title,
    language: language,
    resolution: resolution,
  );
  log.fineWithMetadata(
    "Parsed",
    metadata: {"filename": filename, "anitomyParseResult": anitomyParseResult},
  );
  return anitomyParseResult;
}
