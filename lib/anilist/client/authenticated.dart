import 'package:logging/logging.dart';
import 'package:senpwai/anilist/client.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/exceptions.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/shared.dart';

final _log = Logger("senpwai.anilist.client.authenticated");

class AuthenticatedAnimeSearchParams extends AnimeSearchParams {
  const AuthenticatedAnimeSearchParams({
    super.term,
    super.genres,
    super.season,
    super.seasonYear,
    super.formats,
    super.listStatus,
    super.airingStatuses,
    super.sort,
    super.sortDescending,
    super.page,
    super.perPage,
  });

  @override
  AuthenticatedAnimeSearchParams copyWithPage(int newPage) =>
      AuthenticatedAnimeSearchParams(
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
}

class AnilistAuthenticatedClient extends AnilistClientBase {
  final auth = AnilistAuthenticatorClient();
  final _graphql = AnilistGraphqlClient();
  AnilistContentSettings contentSettings;
  int? viewerId;

  AnilistAuthenticatedClient({
    this.contentSettings = const AnilistContentSettings(),
  });

  Future<int> _getViewerId() async {
    final resolvedViewerId = viewerId ?? (await auth.fetchViewer()).id;
    viewerId = resolvedViewerId;
    return resolvedViewerId;
  }

  Future<Pagination<List<AnilistAnimeWithListEntry>>> listUserMediaList({
    required AnilistMediaListStatus listStatus,
    int page = 1,
    int perPage = 25,
  }) async {
    final token = auth.token;
    if (token == null) {
      throw const AnilistAuthRequiredException();
    }

    final userId = await _getViewerId();
    final query = mediaListSearchQuery();
    final variables = <String, dynamic>{
      "listStatus": listStatus.toGraphql(),
      "userId": userId,
      "page": page,
      "perPage": perPage,
    };
    _log.fineWithMetadata(
      "User media list request prepared",
      metadata: {"userId": userId, "variables": variables},
    );

    final data = await _graphql.postGraphQL(
      query: query,
      variables: variables,
      accessToken: token,
    );
    final pageData = data["data"]?["Page"] as Map<String, dynamic>?;
    final items = mapMediaListItems(pageData, contentSettings: contentSettings);
    final currentPage = (pageData?["pageInfo"]?["currentPage"] as int?) ?? page;
    _log.fineWithMetadata(
      "User media list response parsed",
      metadata: {"page": currentPage, "items": items.length},
    );

    return buildPagination(
      pageData: pageData,
      fallbackPerPage: perPage,
      items: items,
      fetchNextPageCandidate: () => listUserMediaList(
        listStatus: listStatus,
        page: currentPage + 1,
        perPage: perPage,
      ),
    );
  }

  Future<Pagination<List<AnilistAnimeWithListEntry>>> searchAnime({
    AuthenticatedAnimeSearchParams params =
        const AuthenticatedAnimeSearchParams(),
  }) async {
    final token = auth.token;
    if (token == null) {
      throw const AnilistAuthRequiredException();
    }

    final query = mediaSearchQuery(includeListEntry: true);
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

    final data = await _graphql.postGraphQL(
      query: query,
      variables: variables,
      accessToken: token,
    );
    final pageData = data["data"]?["Page"] as Map<String, dynamic>?;
    final items = mapMediaItemsWithListEntry(
      pageData,
      contentSettings: contentSettings,
    );
    final currentPage =
        (pageData?["pageInfo"]?["currentPage"] as int?) ?? params.page;
    final hasNextPage = pageData?["pageInfo"]?["hasNextPage"] as bool?;
    final totalResults = pageData?["pageInfo"]?["total"] as int?;
    _log.fineWithMetadata(
      "AniList search response parsed",
      metadata: {
        "page": currentPage,
        "items": items,
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

  Future<AnilistAnimeWithListEntry?> getAnimeById({
    required int anilistId,
  }) async {
    final token = auth.token;
    if (token == null) {
      throw const AnilistAuthRequiredException();
    }

    final data = await _graphql.postGraphQL(
      query: mediaByIdQuery(includeListEntry: true),
      variables: {"id": anilistId, "isAdult": contentSettings.isAdultQueryValue}
        ..removeWhere((_, value) => value == null),
      accessToken: token,
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
    return AnilistAnimeWithListEntry.fromJson(media);
  }

  Future<List<AnilistRelation<AnilistAnimeWithListEntry>>> fetchRelationsById(
    int anilistId,
  ) async {
    final data = await _graphql.postGraphQL(
      query: mediaByIdQuery(includeListEntry: true),
      variables: {"id": anilistId, "isAdult": contentSettings.isAdultQueryValue}
        ..removeWhere((_, value) => value == null),
      accessToken: auth.token,
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
        parseRelations(
              media,
              (json) => AnilistAnimeWithListEntry.fromJson(json),
            )
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

  Future<List<AnilistRecommendation<AnilistAnimeWithListEntry>>>
  fetchRecommendationsById(int anilistId) async {
    final data = await _graphql.postGraphQL(
      query: mediaByIdQuery(includeListEntry: true),
      variables: {"id": anilistId, "isAdult": contentSettings.isAdultQueryValue}
        ..removeWhere((_, value) => value == null),
      accessToken: auth.token,
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
        parseRecommendations(
              media,
              (json) => AnilistAnimeWithListEntry.fromJson(json),
            )
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

  Future<Pagination<List<AnilistAnimeWithListEntry>>> trendingThisSeason({
    TrendingParams params = const TrendingParams(),
  }) async {
    final now = DateTime.now();
    final season = AnilistSeasonExtension.inferFromDate(now);
    final seasonYear = now.year;
    final token = auth.token;
    if (token == null) {
      throw const AnilistAuthRequiredException();
    }

    final data = await _graphql.postGraphQL(
      query: trendingQuery(includeListEntry: true),
      variables: {
        "season": season.toGraphql(),
        "seasonYear": seasonYear,
        "isAdult": contentSettings.isAdultQueryValue,
        "page": 1,
        "perPage": params.perPage,
      }..removeWhere((_, value) => value == null),
      accessToken: token,
    );
    final pageData = data["data"]?["Page"] as Map<String, dynamic>?;
    final items = mapMediaItemsWithListEntry(
      pageData,
      contentSettings: contentSettings,
    );
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
