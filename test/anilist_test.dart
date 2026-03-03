import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/net_config.dart';
import 'support/support.dart';

void main() {
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    setupLogger();
  });
  final env = dotenv.DotEnv(includePlatformEnvironment: true, quiet: true)
    ..load();
  final authToken = env["ANILIST_AUTH_TOKEN"];

  group("AnilistUnauthenticatedClient", () {
    final client = AnilistUnauthenticatedClient();

    group("cache", () {
      test("cache fetches faster", () async {
        final uncached = await timeIt(
          label: "Searching anime (uncached)",
          fn: () => client.searchAnime(
            params: const AnimeSearchParams(term: "One Piece"),
          ),
        );

        final cached = await timeIt(
          label: "Searching anime (cached)",
          fn: () => client.searchAnime(
            params: const AnimeSearchParams(term: "One Piece"),
          ),
        );
        NetConfig.getInstance().logCache();

        expect(cached.inMilliseconds, lessThan(uncached.inMilliseconds));
      });
    });

    test("searchAnime returns results", () async {
      final results = await client.searchAnime(
        params: const AnimeSearchParams(term: "Fullmetal"),
      );
      expect(results.items, isNotEmpty);
    }, tags: ["unauthenticated"]);

    test("getAnimeById returns media", () async {
      const anilistId = 5114;
      final anime = await client.getAnimeById(anilistId);
      expect(anime, isNotNull);
      expect(anime?.id, anilistId);
    }, tags: ["unauthenticated"]);

    test("trendingThisSeason returns results", () async {
      final results = await client.trendingThisSeason();
      expect(results.items, isNotEmpty);
    }, tags: ["unauthenticated"]);

    test("graphQL client posts requests", () async {
      const query = r'''
          query (
            $id: Int
          ) {
            Media(id: $id, type: ANIME) {
              id
              title { romaji }
            }
          }
        ''';
      final client = AnilistGraphqlClient();
      final data = await client.postGraphQL(
        query: query,
        variables: {"id": 5114},
      );
      final media = data["data"]?["Media"] as Map<String, dynamic>?;
      expect(media, isNotNull);
      expect(media?["id"], 5114);
    }, tags: ["unauthenticated"]);
  });

  group("AnilistAuthenticatedClient", () {
    final client = AnilistAuthenticatedClient();
    final shouldSkip = authToken == null || authToken.isEmpty;
    String requireAuthToken() {
      final token = authToken;
      if (token == null || token.isEmpty) {
        throw StateError("ANILIST_AUTH_TOKEN is required");
      }
      return token;
    }

    setUpAll(() async {
      if (!shouldSkip) {
        await client.auth.setToken(requireAuthToken());
      }
    });

    test(
      "searchAnime returns results",
      () async {
        final results = await client.searchAnime(
          params: const AuthenticatedAnimeSearchParams(term: "Naruto"),
        );
        expect(results.items, isNotEmpty);
      },
      tags: ["authenticated"],
      skip: shouldSkip ? "Set ANILIST_AUTH_TOKEN to run" : false,
    );

    test(
      "getAnimeById returns media with list entry",
      () async {
        const anilistId = 5114;
        final anime = await client.getAnimeById(anilistId: anilistId);
        expect(anime, isNotNull);
        expect(anime?.id, anilistId);
      },
      tags: ["authenticated"],
      skip: shouldSkip ? "Set ANILIST_AUTH_TOKEN to run" : false,
    );

    test(
      "trendingThisSeason returns results",
      () async {
        final results = await client.trendingThisSeason();
        expect(results.items, isNotEmpty);
      },
      tags: ["authenticated"],
      skip: shouldSkip ? "Set ANILIST_AUTH_TOKEN to run" : false,
    );

    test(
      "authenticator validates token",
      () async {
        final isValid = await client.auth.isValidToken(
          token: requireAuthToken(),
        );
        expect(isValid, isTrue);
      },
      tags: ["authenticated"],
      skip: shouldSkip ? "Set ANILIST_AUTH_TOKEN to run" : false,
    );

    test(
      "authenticator fetches viewer",
      () async {
        final viewer = await client.auth.fetchViewer();
        expect(viewer, isNotNull);
        expect(viewer.id, isNotNull);
      },
      tags: ["authenticated"],
      skip: shouldSkip ? "Set ANILIST_AUTH_TOKEN to run" : false,
    );
  });

  group("AnilistAuthenticatorClient", () {});
}
