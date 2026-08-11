import 'dart:convert';

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
  static const _snapshotRefreshInterval = Duration(minutes: 3);

  final auth = AnilistAuthenticatorClient();
  final _graphql = AnilistGraphqlClient();
  AnilistContentSettings contentSettings;
  int? viewerId;
  Map<int, AnilistMediaListEntry> _listEntriesByMediaId = {};
  DateTime? _lastListSnapshotAt;
  Future<bool>? _listSnapshotRequest;
  String? _listSnapshotRequestToken;
  int _snapshotGeneration = 0;

  AnilistAuthenticatedClient({
    this.contentSettings = const AnilistContentSettings(),
  });

  bool get hasUserListSnapshot => _lastListSnapshotAt != null;

  /// Fetches the only user-specific AniList data. This snapshot intentionally
  /// lives in memory only, so every launch starts with a fresh list state.
  Future<bool> ensureUserListSnapshot({bool force = false}) {
    final token = auth.token;
    if (token == null) throw const AnilistAuthRequiredException();
    final isFresh =
        _lastListSnapshotAt != null &&
        DateTime.now().difference(_lastListSnapshotAt!) <
            _snapshotRefreshInterval;
    if (!force && isFresh) return Future.value(false);

    final pending = _listSnapshotRequest;
    if (pending != null && _listSnapshotRequestToken == token) return pending;

    final generation = _snapshotGeneration;
    late final Future<bool> trackedRequest;
    trackedRequest =
        _refreshUserListSnapshot(token: token, generation: generation).then(
          (changed) {
            _clearTrackedSnapshotRequest(trackedRequest);
            return changed;
          },
          onError: (Object error, StackTrace stack) {
            _clearTrackedSnapshotRequest(trackedRequest);
            Error.throwWithStackTrace(error, stack);
          },
        );
    _listSnapshotRequest = trackedRequest;
    _listSnapshotRequestToken = token;
    return trackedRequest;
  }

  void _clearTrackedSnapshotRequest(Future<bool> request) {
    if (!identical(_listSnapshotRequest, request)) return;
    _listSnapshotRequest = null;
    _listSnapshotRequestToken = null;
  }

  Future<bool> _refreshUserListSnapshot({
    required String token,
    required int generation,
  }) async {
    final userId = viewerId ?? (await auth.fetchViewer(accessToken: token)).id;
    final data = await _graphql.postGraphQL(
      query: mediaListSnapshotQuery(),
      variables: {'userId': userId},
      accessToken: token,
    );
    final collection =
        data['data']?['MediaListCollection'] as Map<String, dynamic>?;
    if (collection == null) throw const AnilistEmptyResponseException();
    final lists = collection['lists'] as List<dynamic>? ?? const [];
    final snapshot = <int, AnilistMediaListEntry>{};
    for (final list in lists.whereType<Map<String, dynamic>>()) {
      final entries = list['entries'] as List<dynamic>? ?? const [];
      for (final entry in entries.whereType<Map<String, dynamic>>()) {
        final mediaId = entry['mediaId'] as int?;
        if (mediaId == null) continue;
        snapshot[mediaId] = AnilistMediaListEntry.fromJson(entry);
      }
    }

    if (generation != _snapshotGeneration ||
        auth.token != token ||
        (viewerId != null && viewerId != userId)) {
      return false;
    }

    viewerId = userId;
    final changed = !_snapshotsMatch(_listEntriesByMediaId, snapshot);
    _listEntriesByMediaId = snapshot;
    _lastListSnapshotAt = DateTime.now();
    _log.fineWithMetadata(
      'AniList user list snapshot refreshed',
      metadata: {'userId': userId, 'items': snapshot.length},
    );
    return changed;
  }

  bool _snapshotsMatch(
    Map<int, AnilistMediaListEntry> current,
    Map<int, AnilistMediaListEntry> next,
  ) {
    if (current.length != next.length) return false;
    final currentIds = current.keys.toList(growable: false);
    final nextIds = next.keys.toList(growable: false);
    for (var index = 0; index < currentIds.length; index++) {
      if (currentIds[index] != nextIds[index]) return false;
    }
    for (final MapEntry(key: mediaId, value: nextEntry) in next.entries) {
      final currentEntry = current[mediaId];
      if (currentEntry == null ||
          currentEntry.id != nextEntry.id ||
          currentEntry.status != nextEntry.status ||
          currentEntry.progress != nextEntry.progress ||
          currentEntry.startedAt != nextEntry.startedAt) {
        return false;
      }
    }
    return true;
  }

  void clearUserListSnapshot() {
    _snapshotGeneration++;
    _listEntriesByMediaId = {};
    _lastListSnapshotAt = null;
    _listSnapshotRequest = null;
    _listSnapshotRequestToken = null;
  }

  Future<Map<String, dynamic>> _postCachedAndHydrate({
    required String query,
    Map<String, dynamic>? variables,
  }) async {
    if (auth.token == null) throw const AnilistAuthRequiredException();
    final snapshot = ensureUserListSnapshot();
    final catalogue = _graphql.postGraphQL(query: query, variables: variables);
    final guardedSnapshot = _guardSnapshotForHydration(snapshot);
    final results = await Future.wait<Object>([guardedSnapshot, catalogue]);
    return _hydrateListEntries(results[1] as Map<String, dynamic>);
  }

  Future<bool> _guardSnapshotForHydration(Future<bool> snapshot) async {
    try {
      return await snapshot;
    } on Object catch (error, stack) {
      _log.warning(
        'AniList list snapshot unavailable; returning catalogue data without fresh list state',
        error,
        stack,
      );
      return false;
    }
  }

  Map<String, dynamic> _hydrateListEntries(Map<String, dynamic> data) {
    final hydrated = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    void visit(Object? value) {
      if (value is List) {
        for (final item in value) {
          visit(item);
        }
      } else if (value is Map<String, dynamic>) {
        final children = value.values.toList(growable: false);
        if (value['id'] is int && value['title'] != null) {
          final animeId = value['id'] as int;
          final entry = _listEntriesByMediaId[animeId];
          if (entry != null) {
            value['mediaListEntry'] = _mediaListEntryGraphqlJson(entry);
          }
        }
        for (final child in children) {
          visit(child);
        }
      }
    }

    visit(hydrated);
    return hydrated;
  }

  Map<String, dynamic> _mediaListEntryGraphqlJson(AnilistMediaListEntry entry) {
    final startedAt = entry.startedAt;
    return {
      'id': entry.id,
      'status': entry.status?.toGraphql(),
      'progress': entry.progress,
      'startedAt': startedAt == null
          ? null
          : {
              'year': startedAt.year,
              'month': startedAt.month,
              'day': startedAt.day,
            },
    };
  }

  Future<Pagination<List<AnilistAnimeWithListEntry>>> listUserMediaList({
    required AnilistMediaListStatus listStatus,
    int page = 1,
    int perPage = 25,
  }) async {
    await ensureUserListSnapshot();
    final matchingEntries = _listEntriesByMediaId.entries
        .where((item) => item.value.status == listStatus)
        .toList();
    final totalResults = matchingEntries.length;
    final totalPages = (totalResults / perPage).ceil().clamp(1, 1 << 30);
    final start = (page - 1) * perPage;
    final pageEntries = start >= totalResults
        ? <MapEntry<int, AnilistMediaListEntry>>[]
        : matchingEntries.sublist(
            start,
            (start + perPage).clamp(0, totalResults),
          );
    final ids = pageEntries.map((item) => item.key).toList();
    final items = ids.isEmpty
        ? <AnilistAnimeWithListEntry>[]
        : await _mediaByIds(ids);
    _log.fineWithMetadata(
      "User media list response parsed",
      metadata: {'page': page, 'items': items.length},
    );
    return Pagination(
      currentPage: page,
      totalPages: totalPages,
      totalResults: totalResults,
      perPage: perPage,
      items: items,
      fetchNextPage: page < totalPages
          ? () => listUserMediaList(
              listStatus: listStatus,
              page: page + 1,
              perPage: perPage,
            )
          : null,
    );
  }

  Future<List<AnilistAnimeWithListEntry>> _mediaByIds(List<int> ids) async {
    final data = await _postCachedAndHydrate(
      query: mediaByIdsQuery(includeListEntry: false),
      variables: {
        'ids': ids,
        'isAdult': contentSettings.isAdultQueryValue,
        'perPage': ids.length,
      }..removeWhere((_, value) => value == null),
    );
    final pageData = data['data']?['Page'] as Map<String, dynamic>?;
    final fetched = mapMediaItemsWithListEntry(
      pageData,
      contentSettings: contentSettings,
    );
    final byId = {for (final anime in fetched) anime.id: anime};
    return [
      for (final id in ids)
        if (byId[id] case final anime?) anime,
    ];
  }

  Future<Pagination<List<AnilistAnimeWithListEntry>>> searchAnime({
    AuthenticatedAnimeSearchParams params =
        const AuthenticatedAnimeSearchParams(),
  }) async {
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

    final data = await _postCachedAndHydrate(
      query: query,
      variables: variables,
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
    final data = await _postCachedAndHydrate(
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
    return AnilistAnimeWithListEntry.fromJson(media);
  }

  Future<List<AnilistRelation<AnilistAnimeWithListEntry>>> fetchRelationsById(
    int anilistId,
  ) async {
    final data = await _postCachedAndHydrate(
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
    final data = await _postCachedAndHydrate(
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
    final data = await _postCachedAndHydrate(
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
