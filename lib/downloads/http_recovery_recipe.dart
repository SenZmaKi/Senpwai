/// The source selection, independent of an expiring direct URL. These values
/// identify the selected variant, never the user's current preferences.
class HttpRecoveryRecipe {
  final String animeLocator;
  final int episode;
  final String sourceFileName;
  final String? resolution;
  final String? language;
  final String? linkLocator;
  final int? animeId;

  const HttpRecoveryRecipe({
    required this.animeLocator,
    required this.episode,
    required this.sourceFileName,
    this.resolution,
    this.language,
    this.linkLocator,
    this.animeId,
  });

  Map<String, Object?> toJson() => {
    'animeLocator': animeLocator,
    'episode': episode,
    'sourceFileName': sourceFileName,
    'resolution': resolution,
    'language': language,
    'linkLocator': linkLocator,
    'animeId': animeId,
  };

  factory HttpRecoveryRecipe.fromJson(Map<Object?, Object?> json) =>
      HttpRecoveryRecipe(
        animeLocator: json['animeLocator'] as String,
        episode: json['episode'] as int,
        sourceFileName: json['sourceFileName'] as String,
        resolution: json['resolution'] as String?,
        language: json['language'] as String?,
        linkLocator: json['linkLocator'] as String?,
        animeId: json['animeId'] as int?,
      );
}
