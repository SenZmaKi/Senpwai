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

    final data = await _graphql.postGraphQL(query: query, variables: variables);
    final pageData = data["data"]?["Page"] as Map<String, dynamic>?;
    final items = mapMediaItems(pageData);
    final currentPage =
        (pageData?["pageInfo"]?["currentPage"] as int?) ?? params.page;

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
      return null;
    }
    return AnilistAnime.fromJson(media);
  }

  Future<List<AnilistRelation<AnilistAnime>>> fetchRelationsById(
    int anilistId,
  ) async {
    final data = await _graphql.postGraphQL(
      query: mediaByIdQuery(includeListEntry: false),
      variables: {"id": anilistId},
    );
    final media = data["data"]?["Media"] as Map<String, dynamic>?;
    if (media == null) return [];
    return parseRelations(media, (json) => AnilistAnime.fromJson(json));
  }

  Future<List<AnilistRecommendation<AnilistAnime>>> fetchRecommendationsById(
    int anilistId,
  ) async {
    final data = await _graphql.postGraphQL(
      query: mediaByIdQuery(includeListEntry: false),
      variables: {"id": anilistId},
    );
    final media = data["data"]?["Media"] as Map<String, dynamic>?;
    if (media == null) return [];
    return parseRecommendations(media, (json) => AnilistAnime.fromJson(json));
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

    return buildPagination(
      pageData: pageData,
      fallbackPerPage: params.perPage,
      items: items,
      fetchNextPageCandidate: () => trendingThisSeason(params: params),
    );
  }
}
