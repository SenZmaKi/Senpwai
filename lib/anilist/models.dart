import 'package:senpwai/shared/shared.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/constants.dart' as constants;

abstract class PerPage {
  final int perPage;

  const PerPage({this.perPage = constants.Constants.defaultPerPage});
}

class AnilistTitle with ToJson {
  final String? romaji;
  final String? english;
  final String? native;

  const AnilistTitle({this.romaji, this.english, this.native});

  factory AnilistTitle.fromJson(Map<String, dynamic>? json) => AnilistTitle(
    romaji: json?["romaji"],
    english: json?["english"],
    native: json?["native"],
  );

  @override
  Map<String, dynamic> toMap() => {
    "romaji": romaji,
    "english": english,
    "native": native,
  };

  String get display => english ?? romaji ?? native ?? '?';

  List<String> toTitleCandidates() {
    final titles = <String>[];
    if (romaji != null && romaji!.trim().isNotEmpty) titles.add(romaji!);
    if (english != null && english!.trim().isNotEmpty) titles.add(english!);
    if (native != null && native!.trim().isNotEmpty) titles.add(native!);
    return titles;
  }
}

class AnilistCoverImage with ToJson {
  final String? large;
  final String? medium;

  const AnilistCoverImage({this.large, this.medium});

  factory AnilistCoverImage.fromJson(Map<String, dynamic>? json) =>
      AnilistCoverImage(large: json?["large"], medium: json?["medium"]);

  String? get best => large ?? medium;

  @override
  Map<String, dynamic> toMap() => {"large": large, "medium": medium};
}

class AnilistRelation<T extends ToJson> with ToJson {
  final AnilistRelationType? type;
  final T anime;

  const AnilistRelation({required this.anime, this.type});

  @override
  Map<String, dynamic> toMap() => {
    "relationType": type?.toGraphql(),
    "media": anime.toMap(),
  };
}

class AnilistRecommendation<T extends ToJson> with ToJson {
  final int? rating;
  final T anime;

  const AnilistRecommendation({required this.anime, this.rating});

  @override
  Map<String, dynamic> toMap() => {
    "rating": rating,
    "mediaRecommendation": anime.toMap(),
  };
}

abstract class AnilistAnimeBase<T extends ToJson> with ToJson {
  final int id;
  final AnilistTitle title;
  final AnilistFormat? format;
  final AnilistSeason? season;
  final int? seasonYear;
  final int? episodes;
  final int? episode;
  final DateTime? nextEpisodeAiring;
  final AnilistAiringStatus? status;
  final String? description;
  final List<AnilistGenre> genres;
  final double? averageScore;
  final AnilistCoverImage? coverImage;
  final String? bannerImage;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool? isFavourite;

  const AnilistAnimeBase({
    required this.id,
    required this.title,
    this.format,
    this.season,
    this.seasonYear,
    this.episodes,
    this.episode,
    this.nextEpisodeAiring,
    this.status,
    this.description,
    required this.genres,
    this.averageScore,
    this.coverImage,
    this.bannerImage,
    this.startDate,
    this.endDate,
    this.isFavourite,
  });

  String get seasonLabel => [
    if (season != null) season!.toDisplayLabel(),
    if (seasonYear != null) '$seasonYear',
  ].join(' ');

  @override
  Map<String, dynamic> toMap() => {
    "id": id,
    "title": title.toMap(),
    "format": format?.toGraphql(),
    "season": season?.toGraphql(),
    "seasonYear": seasonYear,
    "episodes": episodes,
    "episode": episode,
    "nextEpisodeAiring": nextEpisodeAiring?.toIso8601String(),
    "status": status?.toGraphql(),
    "description": description,
    "genres": genres.map((genre) => genre.toGraphql()).toList(),
    "averageScore": averageScore,
    "coverImage": coverImage?.toMap(),
    "bannerImage": bannerImage,
    "startDate": startDate?.toIso8601String(),
    "endDate": endDate?.toIso8601String(),
    "isFavourite": isFavourite,
  };
}

class AnilistAnime extends AnilistAnimeBase<AnilistAnime> {
  const AnilistAnime({
    required super.id,
    required super.title,
    super.format,
    super.season,
    super.seasonYear,
    super.episodes,
    super.episode,
    super.nextEpisodeAiring,
    super.status,
    super.description,
    required super.genres,
    super.averageScore,
    super.coverImage,
    super.bannerImage,
    super.startDate,
    super.endDate,
    super.isFavourite,
  });

  factory AnilistAnime.fromJson(Map<String, dynamic> json) {
    final parsed = _parseAnimeFields<AnilistAnime>(
      json,
      (related) => AnilistAnime.fromJson(related),
    );
    return AnilistAnime(
      id: parsed.id,
      title: parsed.title,
      format: parsed.format,
      season: parsed.season,
      seasonYear: parsed.seasonYear,
      episodes: parsed.episodes,
      episode: parsed.episode,
      nextEpisodeAiring: parsed.nextEpisodeAiring,
      status: parsed.status,
      description: parsed.description,
      genres: parsed.genres,
      averageScore: parsed.averageScore,
      coverImage: parsed.coverImage,
      bannerImage: parsed.bannerImage,
      startDate: parsed.startDate,
      endDate: parsed.endDate,
      isFavourite: parsed.isFavourite,
    );
  }
}

class AnilistMediaListEntry with ToJson {
  final int id;
  final AnilistMediaListStatus? status;
  final int? progress;
  final DateTime? startedAt;

  const AnilistMediaListEntry({
    required this.id,
    this.status,
    this.progress,
    this.startedAt,
  });

  factory AnilistMediaListEntry.fromJson(Map<String, dynamic>? json) =>
      AnilistMediaListEntry(
        id: json?["id"],
        status: AnilistMediaListStatusExtension.fromGraphql(json?["status"]),
        progress: json?["progress"],
        startedAt: _parseFuzzyDate(json?["startedAt"] as Map<String, dynamic>?),
      );

  @override
  Map<String, dynamic> toMap() => {
    "id": id,
    "status": status?.toGraphql(),
    "progress": progress,
    "startedAt": startedAt?.toIso8601String(),
  };
}

class AnilistAnimeWithListEntry
    extends AnilistAnimeBase<AnilistAnimeWithListEntry> {
  final AnilistMediaListEntry? listEntry;

  const AnilistAnimeWithListEntry({
    required super.id,
    required super.title,
    super.format,
    super.season,
    super.seasonYear,
    super.episodes,
    super.episode,
    super.nextEpisodeAiring,
    super.status,
    super.description,
    required super.genres,
    super.averageScore,
    super.coverImage,
    super.bannerImage,
    super.startDate,
    super.endDate,
    super.isFavourite,
    this.listEntry,
  });

  factory AnilistAnimeWithListEntry.fromJson(Map<String, dynamic> json) {
    final parsed = _parseAnimeFields<AnilistAnimeWithListEntry>(
      json,
      (related) => AnilistAnimeWithListEntry.fromJson(related),
    );
    return AnilistAnimeWithListEntry(
      id: parsed.id,
      title: parsed.title,
      format: parsed.format,
      season: parsed.season,
      seasonYear: parsed.seasonYear,
      episodes: parsed.episodes,
      episode: parsed.episode,
      nextEpisodeAiring: parsed.nextEpisodeAiring,
      status: parsed.status,
      description: parsed.description,
      genres: parsed.genres,
      averageScore: parsed.averageScore,
      coverImage: parsed.coverImage,
      bannerImage: parsed.bannerImage,
      startDate: parsed.startDate,
      endDate: parsed.endDate,
      isFavourite: parsed.isFavourite,
      listEntry: json["mediaListEntry"] == null
          ? null
          : AnilistMediaListEntry.fromJson(json["mediaListEntry"]),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    ...super.toMap(),
    "mediaListEntry": listEntry?.toMap(),
  };
}

class _ParsedAnimeFields<T extends ToJson> {
  final int id;
  final AnilistTitle title;
  final AnilistFormat? format;
  final AnilistSeason? season;
  final int? seasonYear;
  final int? episodes;
  final int? episode;
  final DateTime? nextEpisodeAiring;
  final AnilistAiringStatus? status;
  final String? description;
  final List<AnilistGenre> genres;
  final double? averageScore;
  final AnilistCoverImage? coverImage;
  final String? bannerImage;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool? isFavourite;

  const _ParsedAnimeFields({
    required this.id,
    required this.title,
    this.format,
    this.season,
    this.seasonYear,
    this.episodes,
    this.episode,
    this.nextEpisodeAiring,
    this.status,
    this.description,
    required this.genres,
    this.averageScore,
    this.coverImage,
    this.bannerImage,
    this.startDate,
    this.endDate,
    this.isFavourite,
  });
}

_ParsedAnimeFields<T> _parseAnimeFields<T extends ToJson>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic>) relatedParser,
) {
  final nextAiring = json["nextAiringEpisode"] as Map<String, dynamic>?;
  final episodeValue = nextAiring?["episode"];
  final episode = episodeValue is num ? episodeValue.toInt() : null;
  final airingAtValue = nextAiring?["airingAt"];
  final nextEpisodeAiring = airingAtValue is num
      ? DateTime.fromMillisecondsSinceEpoch(
          airingAtValue.toInt() * 1000,
          isUtc: true,
        )
      : null;
  return _ParsedAnimeFields(
    id: json["id"],
    title: AnilistTitle.fromJson(json["title"]),
    format: AnilistFormatExtension.fromGraphql(json["format"]),
    season: AnilistSeasonExtension.fromGraphql(json["season"]),
    seasonYear: json["seasonYear"],
    episodes: json["episodes"],
    episode: episode,
    nextEpisodeAiring: nextEpisodeAiring,
    status: AnilistAiringStatusExtension.fromGraphql(json["status"]),
    description: json["description"],
    genres: (json["genres"] as List<dynamic>? ?? [])
        .whereType<String>()
        .map(AnilistGenreExtension.fromGraphql)
        .whereType<AnilistGenre>()
        .toList(),
    averageScore: (json["averageScore"] as num?)?.toDouble(),
    coverImage: json["coverImage"] == null
        ? null
        : AnilistCoverImage.fromJson(json["coverImage"]),
    bannerImage: json["bannerImage"] as String?,
    startDate: _parseFuzzyDate(json["startDate"] as Map<String, dynamic>?),
    endDate: _parseFuzzyDate(json["endDate"] as Map<String, dynamic>?),
    isFavourite: json["isFavourite"] as bool?,
  );
}

DateTime? _parseFuzzyDate(Map<String, dynamic>? json) {
  if (json == null) {
    return null;
  }
  final year = json["year"] as num?;
  if (year == null) {
    return null;
  }
  final month = (json["month"] as num?)?.toInt() ?? 1;
  final day = (json["day"] as num?)?.toInt() ?? 1;
  return DateTime.utc(year.toInt(), month, day);
}

List<AnilistRelation<T>> parseRelations<T extends ToJson>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic>) relatedParser,
) {
  final relations = json["relations"] as Map<String, dynamic>?;
  final edges = (relations?["edges"] as List<dynamic>? ?? []);
  final nodes = (relations?["nodes"] as List<dynamic>? ?? []);
  final results = <AnilistRelation<T>>[];
  for (var index = 0; index < nodes.length; index++) {
    final node = nodes[index];
    if (node is! Map<String, dynamic>) {
      continue;
    }
    AnilistRelationType? type;
    if (index < edges.length) {
      final edge = edges[index];
      if (edge is Map<String, dynamic>) {
        type = AnilistRelationTypeExtension.fromGraphql(edge["relationType"]);
      }
    }
    results.add(AnilistRelation(type: type, anime: relatedParser(node)));
  }
  return results;
}

List<AnilistRecommendation<T>> parseRecommendations<T extends ToJson>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic>) relatedParser,
) {
  final recommendations = json["recommendations"] as Map<String, dynamic>?;
  final nodes = (recommendations?["nodes"] as List<dynamic>? ?? []);
  final results = <AnilistRecommendation<T>>[];
  for (final node in nodes) {
    if (node is! Map<String, dynamic>) {
      continue;
    }
    final media = node["mediaRecommendation"] as Map<String, dynamic>?;
    if (media == null) {
      continue;
    }
    final ratingValue = node["rating"];
    final rating = ratingValue is num ? ratingValue.toInt() : null;
    results.add(
      AnilistRecommendation(anime: relatedParser(media), rating: rating),
    );
  }
  return results;
}

class AnimeSearchParams extends PerPage {
  final String? term;
  final List<AnilistGenre>? genres;
  final AnilistSeason? season;
  final int? seasonYear;
  final List<AnilistFormat>? formats;
  final AnilistMediaListStatus? listStatus;
  final List<AnilistAiringStatus>? airingStatuses;
  final AnilistMediaSort? sort;
  final bool sortDescending;
  final int page;

  const AnimeSearchParams({
    this.term,
    this.genres,
    this.season,
    this.seasonYear,
    this.formats,
    this.listStatus,
    this.airingStatuses,
    this.sort,
    this.sortDescending = true,
    this.page = 1,
    super.perPage,
  });

  AnimeSearchParams copyWithPage(int newPage) => AnimeSearchParams(
    term: term,
    genres: genres,
    season: season,
    seasonYear: seasonYear,
    formats: formats,
    listStatus: listStatus,
    airingStatuses: airingStatuses,
    sort: sort,
    sortDescending: sortDescending,
    page: newPage,
    perPage: perPage,
  );

  @override
  String toString() =>
      "AnimeSearchParams(term: $term, genres: $genres, season: $season, seasonYear: $seasonYear, formats: $formats, listStatus: $listStatus, airingStatuses: $airingStatuses, sort: $sort, sortDescending: $sortDescending, page: $page, perPage: $perPage)";
}

class TrendingParams extends PerPage {
  const TrendingParams({super.perPage});
}

class AnilistViewer {
  final int id;
  final String name;
  final String? avatarLarge;
  final String? avatarMedium;

  const AnilistViewer({
    required this.id,
    required this.name,
    this.avatarLarge,
    this.avatarMedium,
  });

  String? get avatarUrl => avatarLarge ?? avatarMedium;

  factory AnilistViewer.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar'] as Map<String, dynamic>?;
    return AnilistViewer(
      id: json['id'] as int,
      name: json['name'] as String,
      avatarLarge: avatar?['large'] as String?,
      avatarMedium: avatar?['medium'] as String?,
    );
  }
}
