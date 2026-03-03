import 'package:logging/logging.dart';
import 'package:senpwai/anilist/client/shared.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/exceptions.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/shared.dart';

final _log = Logger("senpwai.anilist.client.unauthenticated");

class AnilistUnauthenticatedClient extends AnilistClientBase {
  final _graphql = AnilistGraphqlClient();

  Future<Pagination<List<AnilistAnime>>> searchAnime({
    AnimeSearchParams params = const AnimeSearchParams(),
  }) async {
    _log.infoWithMetadata("Searching AniList", metadata: {"params": params});
    if (params.listStatus != null) {
      throw const AnilistAuthRequiredException();
    }
    final query = mediaSearchQuery(includeListEntry: false);
    final variables = buildSearchVariables(params);
    _log.fineWithMetadata(
      "AniList search request prepared",
      metadata: {
        "page": params.page,
        "perPage": params.perPage,
        "variables": variables,
      },
    );

    final data = await _graphql.postGraphQL(query: query, variables: variables);
    final pageData = data["data"]?["Page"] as Map<String, dynamic>?;
    final items = mapMediaItems(pageData);
    final currentPage =
        (pageData?["pageInfo"]?["currentPage"] as int?) ?? params.page;
    final hasNextPage = pageData?["pageInfo"]?["hasNextPage"] as bool?;
    final totalResults = pageData?["pageInfo"]?["total"] as int?;
    _log.fineWithMetadata(
      "AniList search response parsed",
      metadata: {
        "page": currentPage,
        "items": items.length,
        "total": totalResults,
        "hasNextPage": hasNextPage,
      },
    );

    return buildPagination(
      pageData: pageData,
      fallbackPerPage: params.perPage,
      items: items,
      fetchNextPageCandidate: () =>
          searchAnime(params: params.copyWithPage(currentPage + 1)),
    );
  }

  Future<AnilistAnime?> getAnimeById(int anilistId) async {
    _log.infoWithMetadata(
      "Fetching AniList anime by ID",
      metadata: {"anilistId": anilistId},
    );
    final data = await _graphql.postGraphQL(
      query: mediaByIdQuery(includeListEntry: false),
      variables: {"id": anilistId},
    );
    final media = data["data"]?["Media"] as Map<String, dynamic>?;
    if (media == null) {
      _log.warningWithMetadata(
        "AniList anime not found by ID",
        metadata: {"anilistId": anilistId},
      );
      return null;
    }
    _log.fineWithMetadata(
      "AniList anime fetched by ID",
      metadata: {"anilistId": anilistId},
    );
    return AnilistAnime.fromJson(media);
  }

  Future<List<AnilistRelation<AnilistAnime>>> fetchRelationsById(
    int anilistId,
  ) async {
    _log.infoWithMetadata(
      "Fetching AniList relations by ID",
      metadata: {"anilistId": anilistId},
    );
    final data = await _graphql.postGraphQL(
      query: mediaByIdQuery(includeListEntry: false),
      variables: {"id": anilistId},
    );
    final media = data["data"]?["Media"] as Map<String, dynamic>?;
    if (media == null) {
      _log.warningWithMetadata(
        "AniList relations source media missing",
        metadata: {"anilistId": anilistId},
      );
      return [];
    }
    final relations = parseRelations(
      media,
      (json) => AnilistAnime.fromJson(json),
    );
    _log.fineWithMetadata(
      "AniList relations fetched",
      metadata: {"anilistId": anilistId, "count": relations.length},
    );
    return relations;
  }

  Future<List<AnilistRecommendation<AnilistAnime>>> fetchRecommendationsById(
    int anilistId,
  ) async {
    _log.infoWithMetadata(
      "Fetching AniList recommendations by ID",
      metadata: {"anilistId": anilistId},
    );
    final data = await _graphql.postGraphQL(
      query: mediaByIdQuery(includeListEntry: false),
      variables: {"id": anilistId},
    );
    final media = data["data"]?["Media"] as Map<String, dynamic>?;
    if (media == null) {
      _log.warningWithMetadata(
        "AniList recommendations source media missing",
        metadata: {"anilistId": anilistId},
      );
      return [];
    }
    final recommendations = parseRecommendations(
      media,
      (json) => AnilistAnime.fromJson(json),
    );
    _log.fineWithMetadata(
      "AniList recommendations fetched",
      metadata: {"anilistId": anilistId, "count": recommendations.length},
    );
    return recommendations;
  }

  Future<Pagination<List<AnilistAnime>>> trendingThisSeason({
    TrendingParams params = const TrendingParams(),
  }) async {
    final now = DateTime.now();
    final season = AnilistSeasonExtension.inferFromDate(now);
    final seasonYear = now.year;
    _log.infoWithMetadata(
      "Fetching AniList trending season",
      metadata: {"season": season, "seasonYear": seasonYear},
    );

    final data = await _graphql.postGraphQL(
      query: trendingQuery(includeListEntry: false),
      variables: {
        "season": season.toGraphql(),
        "seasonYear": seasonYear,
        "page": 1,
        "perPage": params.perPage,
      },
    );
    final pageData = data["data"]?["Page"] as Map<String, dynamic>?;
    final items = mapMediaItems(pageData);
    final totalResults = pageData?["pageInfo"]?["total"] as int?;
    final hasNextPage = pageData?["pageInfo"]?["hasNextPage"] as bool?;
    _log.fineWithMetadata(
      "AniList trending season fetched",
      metadata: {
        "season": season,
        "seasonYear": seasonYear,
        "items": items.length,
        "total": totalResults,
        "hasNextPage": hasNextPage,
      },
    );

    return buildPagination(
      pageData: pageData,
      fallbackPerPage: params.perPage,
      items: items,
      fetchNextPageCandidate: () => trendingThisSeason(params: params),
    );
  }
}
