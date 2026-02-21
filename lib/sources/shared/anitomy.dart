import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/sources/shared/shared.dart';
import 'package:anitomy_dart/anitomy.dart' as anitomy;

final _ani = anitomy.Anitomy();
Logger log = Logger("senpwai.sources.shared.anitomy.anitomy");

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

AnitomyParseResult parseFilename(String filename) {
  log.infoWithMetadata("Parsing filename", metadata: {"filename": filename});
  _ani.parse(filename);
  final elements = _ani.elements.items.toList();
  final season = _parseCategory(
    elements: elements,
    category: anitomy.ElementCategory.animeSeason,
    parser: (elementValue) => int.parse(elementValue),
  );
  final episode = _parseCategory(
    elements: elements,
    category: anitomy.ElementCategory.episodeNumber,
    parser: (elementValue) => int.parse(elementValue),
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
