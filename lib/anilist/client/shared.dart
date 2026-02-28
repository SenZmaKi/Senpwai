import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anilist/constants.dart' as constants;
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/exceptions.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/net/net_config.dart';
import 'package:senpwai/shared/shared.dart';
import 'package:senpwai/anitomy/anitomy.dart';

final _log = Logger("senpwai.anilist.client");

const _mediaCoreFields = r'''
  id
  title { romaji english native }
  format
  season
  seasonYear
  startDate { year month day }
  endDate { year month day }
  episodes
  nextAiringEpisode { episode airingAt }
  status
  description
  genres
  averageScore
  coverImage { large medium }
  bannerImage
  isFavourite
''';

const _mediaListEntryFields = r'''
  mediaListEntry {
    id
    status
    progress
    startedAt { year month day }
  }
''';

class AnilistGraphqlClient {
  final _dio = GlobalDio.getInstance();

  AnilistGraphqlClient();

  Future<Map<String, dynamic>> postGraphQL({
    required String query,
    Map<String, dynamic>? variables,
    String? accessToken,
  }) async {
    _log.infoWithMetadata(
      "Posting GraphQL request",
      metadata: {"variables": variables},
    );
    final response = await _dio.post<Map<String, dynamic>>(
      constants.Constants.apiEntryPoint,
      data: {"query": query, "variables": variables},
      options: Options(
        headers: accessToken == null
            ? null
            : {"Authorization": "Bearer $accessToken"},
        extra: NetConfig.getInstance()
            .buildCacheOptions(allowPostMethod: true)
            .toExtra(),
      ),
    );
    final data = response.data;
    if (data == null) {
      throw const AnilistEmptyResponseException();
    }
    return data;
  }
}

class AnilistTitleMatch {
  final String inputTitle;
  final int score;

  const AnilistTitleMatch({required this.inputTitle, required this.score});
}

abstract class AnilistClientBase {
  String deriveSearchTerm(String inputTitle) {
    final parsed = parseFilename(inputTitle);
    return parsed.title ?? inputTitle;
  }

  List<AnilistTitleMatch> sortByBestMatch({
    required AnilistAnimeBase anime,
    required List<String> inputTitles,
  }) {
    final titleCandidates = anime.title.toTitleCandidates();
    if (titleCandidates.isEmpty || inputTitles.isEmpty) {
      return [];
    }

    final matches = inputTitles.map((inputTitle) {
      final parsed = parseFilename(inputTitle);
      final candidateTitle = parsed.title ?? inputTitle;
      final baseScore = titleCandidates
          .map((title) => weightedRatio(candidateTitle, title))
          .reduce((value, element) => value > element ? value : element);
      var score = baseScore;
      if (parsed.season != null) {
        final seasonNumber = _inferSeasonNumber(anime);
        score += seasonNumber == parsed.season ? 8 : -10;
      }
      return AnilistTitleMatch(inputTitle: inputTitle, score: score);
    }).toList();

    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches;
  }

  int _inferSeasonNumber(AnilistAnimeBase anime) {
    // Relations are lazy-loaded; default to season 1 for sync matching
    return 1;
  }
}

String _mediaFields({required bool includeListEntry}) {
  final listEntryFields = includeListEntry ? _mediaListEntryFields : "";
  return '''
    $_mediaCoreFields
    $listEntryFields
  ''';
}

String _relationFields({required bool includeListEntry}) {
  return '''
    relations {
      edges { relationType }
      nodes {
        ${_mediaFields(includeListEntry: includeListEntry)}
      }
    }
  ''';
}

String _recommendationFields({required bool includeListEntry}) {
  return '''
    recommendations {
      nodes {
        rating
        mediaRecommendation {
          ${_mediaFields(includeListEntry: includeListEntry)}
        }
      }
    }
  ''';
}

String mediaSearchQuery({required bool includeListEntry}) {
  return '''
      query (
        \$search: String,
        \$genreIn: [String],
        \$season: MediaSeason,
        \$seasonYear: Int,
        \$format: MediaFormat,
        \$status: MediaStatus,
        \$sort: [MediaSort],
        \$page: Int,
        \$perPage: Int
      ) {
        Page(page: \$page, perPage: \$perPage) {
          pageInfo { currentPage lastPage perPage total }
          media(
            search: \$search,
            genre_in: \$genreIn,
            season: \$season,
            seasonYear: \$seasonYear,
            format: \$format,
            status: \$status,
            type: ANIME,
            sort: \$sort
          ) {
            ${_mediaFields(includeListEntry: includeListEntry)}
          }
        }
      }
    ''';
}

String mediaByIdQuery({required bool includeListEntry}) {
  return '''
      query (\$id: Int) {
        Media(id: \$id, type: ANIME) {
          ${_mediaFields(includeListEntry: includeListEntry)}
          ${_relationFields(includeListEntry: includeListEntry)}
          ${_recommendationFields(includeListEntry: includeListEntry)}
        }
      }
    ''';
}

String trendingQuery({required bool includeListEntry}) {
  return '''
      query (\$season: MediaSeason, \$seasonYear: Int, \$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          pageInfo { currentPage lastPage perPage total }
          media(
            season: \$season,
            seasonYear: \$seasonYear,
            type: ANIME,
            sort: [TRENDING_DESC, POPULARITY_DESC]
          ) {
            ${_mediaFields(includeListEntry: includeListEntry)}
          }
        }
      }
    ''';
}

String mediaListSearchQuery() {
  return '''
      query (
        \$search: String,
        \$listStatus: MediaListStatus,
        \$page: Int,
        \$perPage: Int
      ) {
        Page(page: \$page, perPage: \$perPage) {
          pageInfo { currentPage lastPage perPage total }
          mediaList(search: \$search, status: \$listStatus, type: ANIME) {
            id
            status
            progress
            startedAt { year month day }
            media {
              ${_mediaFields(includeListEntry: false)}
            }
          }
        }
      }
    ''';
}

Map<String, dynamic> buildSearchVariables(AnimeSearchParams params) {
  // Build sort list: use explicit sort if provided, otherwise default
  List<String>? sortList;
  if (params.sort != null) {
    final sortValue = params.sortDescending
        ? params.sort!.toGraphqlDesc()
        : params.sort!.toGraphqlAsc();
    sortList = [sortValue];
  } else if (params.term != null && params.term!.isNotEmpty) {
    sortList = ["SEARCH_MATCH", "POPULARITY_DESC"];
  } else {
    sortList = ["POPULARITY_DESC"];
  }

  final variables = <String, dynamic>{
    "search": params.term,
    "genreIn": params.genres?.map((genre) => genre.toGraphql()).toList(),
    "season": params.season?.toGraphql(),
    "seasonYear": params.seasonYear,
    "format": params.format?.toGraphql(),
    "status": params.airingStatus?.toGraphql(),
    "listStatus": params.listStatus?.toGraphql(),
    "sort": sortList,
    "page": params.page,
    "perPage": params.perPage,
  }..removeWhere((_, value) => value == null);

  return variables;
}

Pagination<List<T>> buildPagination<T>({
  required Map<String, dynamic>? pageData,
  required int fallbackPerPage,
  required List<T> items,
  required Future<Pagination<List<T>>> Function()? fetchNextPageCandidate,
}) {
  final pageInfo = pageData?["pageInfo"] as Map<String, dynamic>?;
  final currentPage = pageInfo?["currentPage"] ?? 1;
  final totalPages = pageInfo?["lastPage"] ?? 1;
  final resolvedPerPage = pageInfo?["perPage"] ?? fallbackPerPage;
  final total = pageInfo?["total"] as int?;
  final fetchNextPage = currentPage < totalPages
      ? fetchNextPageCandidate
      : null;

  return Pagination(
    currentPage: currentPage,
    totalPages: totalPages,
    items: items,
    fetchNextPage: fetchNextPage,
    perPage: resolvedPerPage,
    totalResults: total ?? (totalPages * resolvedPerPage),
  );
}

List<AnilistAnime> mapMediaItems(Map<String, dynamic>? pageData) {
  final media = (pageData?["media"] as List<dynamic>? ?? []);
  return media
      .whereType<Map<String, dynamic>>()
      .map((json) => AnilistAnime.fromJson(json))
      .toList();
}

List<AnilistAnimeWithListEntry> mapMediaItemsWithListEntry(
  Map<String, dynamic>? pageData,
) {
  final media = (pageData?["media"] as List<dynamic>? ?? []);
  return media
      .whereType<Map<String, dynamic>>()
      .map((json) => AnilistAnimeWithListEntry.fromJson(json))
      .toList();
}

List<AnilistAnimeWithListEntry> mapMediaListItems(
  Map<String, dynamic>? pageData,
) {
  final listItems = (pageData?["mediaList"] as List<dynamic>? ?? []);
  return listItems.whereType<Map<String, dynamic>>().map((json) {
    final media = json["media"] as Map<String, dynamic>;
    return AnilistAnimeWithListEntry.fromJson({
      ...media,
      "mediaListEntry": json,
    });
  }).toList();
}
