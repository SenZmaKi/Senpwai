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
  AnilistContentSettings contentSettings;

  AnilistUnauthenticatedClient({
    this.contentSettings = const AnilistContentSettings(),
  });

  Future<Pagination<List<AnilistAnime>>> searchAnime({
    AnimeSearchParams params = const AnimeSearchParams(),
  }) async {
    if (params.listStatus != null) {
      throw const AnilistAuthRequiredException();
    }
    final query = mediaSearchQuery(includeListEntry: false);
    final variables = buildSearchVariables(
      params,
      contentSettings: contentSettings,
    );
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
    final items = mapMediaItems(pageData, contentSettings: contentSettings);
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
    final data = await _graphql.postGraphQL(
      query: mediaByIdQuery(includeListEntry: false),
      variables: {"id": anilistId, "isAdult": contentSettings.isAdultQueryValue}
        ..removeWhere((_, value) => value == null),
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
    final data = await _graphql.postGraphQL(
      query: mediaByIdQuery(includeListEntry: false),
      variables: {"id": anilistId, "isAdult": contentSettings.isAdultQueryValue}
        ..removeWhere((_, value) => value == null),
    );
    final media = data["data"]?["Media"] as Map<String, dynamic>?;
    if (media == null) {
      _log.warningWithMetadata(
        "AniList relations source media missing",
        metadata: {"anilistId": anilistId},
      );
      return [];
    }
    final relations =
        parseRelations(media, (json) => AnilistAnime.fromJson(json))
            .where(
              (relation) =>
                  contentSettings.showAdultContent ||
                  relation.anime.isAdult != true,
            )
            .toList();
    _log.fineWithMetadata(
      "AniList relations fetched",
      metadata: {"anilistId": anilistId, "count": relations.length},
    );
    return relations;
  }

  Future<List<AnilistRecommendation<AnilistAnime>>> fetchRecommendationsById(
    int anilistId,
  ) async {
    final data = await _graphql.postGraphQL(
      query: mediaByIdQuery(includeListEntry: false),
      variables: {"id": anilistId, "isAdult": contentSettings.isAdultQueryValue}
        ..removeWhere((_, value) => value == null),
    );
    final media = data["data"]?["Media"] as Map<String, dynamic>?;
    if (media == null) {
      _log.warningWithMetadata(
        "AniList recommendations source media missing",
        metadata: {"anilistId": anilistId},
      );
      return [];
    }
    final recommendations =
        parseRecommendations(media, (json) => AnilistAnime.fromJson(json))
            .where(
              (recommendation) =>
                  contentSettings.showAdultContent ||
                  recommendation.anime.isAdult != true,
            )
            .toList();
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

    final data = await _graphql.postGraphQL(
      query: trendingQuery(includeListEntry: false),
      variables: {
        "season": season.toGraphql(),
        "seasonYear": seasonYear,
        "isAdult": contentSettings.isAdultQueryValue,
        "page": 1,
        "perPage": params.perPage,
      }..removeWhere((_, value) => value == null),
    );
    final pageData = data["data"]?["Page"] as Map<String, dynamic>?;
    final items = mapMediaItems(pageData, contentSettings: contentSettings);
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
