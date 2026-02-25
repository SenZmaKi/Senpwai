import 'package:logging/logging.dart';
import 'package:senpwai/anilist/client.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/exceptions.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/shared.dart';
import 'package:senpwai/anilist/constants.dart' as constants;

final _log = Logger("senpwai.anilist.client.authenticated");

class AuthenticatedAnimeSearchParams extends AnimeSearchParams {
  /// Only include user list entries in the results.
  final bool onlyIncludeUserListEntry;

  const AuthenticatedAnimeSearchParams({
    super.term,
    super.genres,
    super.season,
    super.seasonYear,
    super.format,
    super.listStatus,
    super.perPage,
    this.onlyIncludeUserListEntry = false,
  });
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

    return buildPagination(
      pageData: pageData,
      fallbackPerPage: params.perPage,
      items: items,
      fetchNextPageCandidate: () => searchAnime(params: params),
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

  Future<AnilistAnimeWithListEntry?> matchAnimeTitle({
    required String inputTitle,
    int minMatchScore = 90,
    int perPage = constants.Constants.defaultPerPage,
  }) async {
    _log.infoWithMetadata(
      "Matching anime title",
      metadata: {"inputTitle": inputTitle, "minMatchScore": minMatchScore},
    );
    final searchTerm = deriveSearchTerm(inputTitle);
    final inputTitles = {inputTitle, searchTerm}.toList();
    final results = await searchAnime(
      params: AuthenticatedAnimeSearchParams(
        term: searchTerm,
        perPage: perPage,
      ),
    );
    if (results.items.isEmpty) {
      return null;
    }

    AnilistAnimeWithListEntry? best;
    var bestScore = -1;
    for (final anime in results.items) {
      final matches = sortByBestMatch(anime: anime, inputTitles: inputTitles);
      if (matches.isEmpty) {
        continue;
      }
      final score = matches.first.score;
      if (score > bestScore) {
        bestScore = score;
        best = anime;
      }
    }

    if (best == null || bestScore < minMatchScore) {
      _log.infoWithMetadata(
        "No anime match met threshold",
        metadata: {"bestScore": bestScore},
      );
      return null;
    }

    _log.infoWithMetadata(
      "Matched anime title",
      metadata: {"bestScore": bestScore, "animeId": best.id},
    );
    return best;
  }
}
