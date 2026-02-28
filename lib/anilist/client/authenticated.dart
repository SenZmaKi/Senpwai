import 'package:logging/logging.dart';
import 'package:senpwai/anilist/client.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/exceptions.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/shared.dart';

final _log = Logger("senpwai.anilist.client.authenticated");

class AuthenticatedAnimeSearchParams extends AnimeSearchParams {
  final bool onlyIncludeUserListEntry;

  const AuthenticatedAnimeSearchParams({
    super.term,
    super.genres,
    super.season,
    super.seasonYear,
    super.format,
    super.listStatus,
    super.airingStatus,
    super.sort,
    super.sortDescending,
    super.page,
    super.perPage,
    this.onlyIncludeUserListEntry = false,
  });

  @override
  AuthenticatedAnimeSearchParams copyWithPage(int newPage) =>
      AuthenticatedAnimeSearchParams(
        term: term,
        genres: genres,
        season: season,
        seasonYear: seasonYear,
        format: format,
        listStatus: listStatus,
        airingStatus: airingStatus,
        sort: sort,
        sortDescending: sortDescending,
        page: newPage,
        perPage: perPage,
        onlyIncludeUserListEntry: onlyIncludeUserListEntry,
      );
}

class AnilistAuthenticatedClient extends AnilistClientBase {
  final auth = AnilistAuthenticatorClient();
  final _graphql = AnilistGraphqlClient();

  AnilistAuthenticatedClient();

  Future<Pagination<List<AnilistAnimeWithListEntry>>> searchAnime({
    AuthenticatedAnimeSearchParams params =
        const AuthenticatedAnimeSearchParams(),
  }) async {
    _log.infoWithMetadata("Searching AniList", metadata: {"params": params});
    final token = auth.token;
    if (token == null) {
      throw const AnilistAuthRequiredException();
    }

    final query = params.onlyIncludeUserListEntry
        ? mediaListSearchQuery()
        : mediaSearchQuery(includeListEntry: true);
    final variables = buildSearchVariables(params);

    final data = await _graphql.postGraphQL(
      query: query,
      variables: variables,
      accessToken: token,
    );
    final pageData = data["data"]?["Page"] as Map<String, dynamic>?;
    final items = params.onlyIncludeUserListEntry
        ? mapMediaListItems(pageData)
        : mapMediaItemsWithListEntry(pageData);
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

  Future<AnilistAnimeWithListEntry?> getAnimeById({
    required int anilistId,
  }) async {
    _log.infoWithMetadata(
      "Fetching AniList anime by ID",
      metadata: {"anilistId": anilistId},
    );
    final token = auth.token;
    if (token == null) {
      throw const AnilistAuthRequiredException();
    }

    final data = await _graphql.postGraphQL(
      query: mediaByIdQuery(includeListEntry: true),
      variables: {"id": anilistId},
      accessToken: token,
    );
    final media = data["data"]?["Media"] as Map<String, dynamic>?;
    if (media == null) {
      return null;
    }
    return AnilistAnimeWithListEntry.fromJson(media);
  }

  Future<List<AnilistRelation<AnilistAnimeWithListEntry>>> fetchRelationsById(
    int anilistId,
  ) async {
    final data = await _graphql.postGraphQL(
      query: mediaByIdQuery(includeListEntry: true),
      variables: {"id": anilistId},
      accessToken: auth.token,
    );
    final media = data["data"]?["Media"] as Map<String, dynamic>?;
    if (media == null) return [];
    return parseRelations(
      media,
      (json) => AnilistAnimeWithListEntry.fromJson(json),
    );
  }

  Future<List<AnilistRecommendation<AnilistAnimeWithListEntry>>>
  fetchRecommendationsById(int anilistId) async {
    final data = await _graphql.postGraphQL(
      query: mediaByIdQuery(includeListEntry: true),
      variables: {"id": anilistId},
      accessToken: auth.token,
    );
    final media = data["data"]?["Media"] as Map<String, dynamic>?;
    if (media == null) return [];
    return parseRecommendations(
      media,
      (json) => AnilistAnimeWithListEntry.fromJson(json),
    );
  }

  Future<Pagination<List<AnilistAnimeWithListEntry>>> trendingThisSeason({
    TrendingParams params = const TrendingParams(),
  }) async {
    final now = DateTime.now();
    final season = AnilistSeasonExtension.inferFromDate(now);
    final seasonYear = now.year;
    _log.infoWithMetadata(
      "Fetching AniList trending season",
      metadata: {"season": season, "seasonYear": seasonYear},
    );
    final token = auth.token;
    if (token == null) {
      throw const AnilistAuthRequiredException();
    }

    final data = await _graphql.postGraphQL(
      query: trendingQuery(includeListEntry: true),
      variables: {
        "season": season.toGraphql(),
        "seasonYear": seasonYear,
        "page": 1,
        "perPage": params.perPage,
      },
      accessToken: token,
    );
    final pageData = data["data"]?["Page"] as Map<String, dynamic>?;
    final items = mapMediaItemsWithListEntry(pageData);

    return buildPagination(
      pageData: pageData,
      fallbackPerPage: params.perPage,
      items: items,
      fetchNextPageCandidate: () => trendingThisSeason(params: params),
    );
  }
}
