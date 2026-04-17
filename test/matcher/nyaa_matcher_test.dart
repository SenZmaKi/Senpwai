import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/sources/shared/matcher/nyaa.dart';
import 'package:senpwai/sources/shared/shared.dart';

final _log = Logger("senpwai.sources.nyaa.matcher.test");

void main() {
  late AnilistUnauthenticatedClient anilistClient;
  late NyaaMatcher matcher;
  const params = NyaaMatchParams(
    preferredResolution: Resolution.res1080p,
    preferredLanguage: Language.english,
  );

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    setupLogger();
    anilistClient = AnilistUnauthenticatedClient();
    matcher = NyaaMatcher();
  });

  group("matchSeason", () {
    Future<void> expectSeasonMatch(int anilistId, String label) async {
      final anime = await anilistClient.getAnimeById(anilistId);
      expect(
        anime,
        isNotNull,
        reason: "$label: AniList ID $anilistId should exist",
      );
      final matches = await matcher.matchSeason(anime!, params);
      expect(
        matches,
        isNotEmpty,
        reason: "$label: should find season Nyaa matches",
      );
      final best = matches.first;
      _log.infoWithMetadata(
        "Best Nyaa season match for $label",
        metadata: {
          "anilistTitle": anime.title.display,
          "filename": best.result.filename,
          "score": best.score,
          "resolution": best.resolution.toString(),
          "seeders": best.result.seeders,
        },
      );
      expect(
        best.result.sizeBytes,
        greaterThan(0),
        reason: "$label: matched result should have a positive size",
      );
      expect(
        best.result.seeders,
        greaterThan(0),
        reason: "$label: matched result should have seeders (zero-seeder results are filtered)",
      );
    }

    test(
      "matches Death Note season",
      () => expectSeasonMatch(1535, "Death Note"),
    );
    test(
      "matches Fullmetal Alchemist Brotherhood season",
      () => expectSeasonMatch(5114, "Fullmetal Alchemist Brotherhood"),
    );
    test(
      "matches Steins;Gate season",
      () => expectSeasonMatch(9253, "Steins;Gate"),
    );
  });

  group("matchMovie", () {
    Future<void> expectMovieMatch(int anilistId, String label) async {
      final anime = await anilistClient.getAnimeById(anilistId);
      expect(
        anime,
        isNotNull,
        reason: "$label: AniList ID $anilistId should exist",
      );
      final matches = await matcher.matchMovie(anime!, params);
      expect(
        matches,
        isNotEmpty,
        reason: "$label: should find movie Nyaa matches",
      );
      final best = matches.first;
      _log.infoWithMetadata(
        "Best Nyaa movie match for $label",
        metadata: {
          "anilistTitle": anime.title.display,
          "filename": best.result.filename,
          "score": best.score,
          "resolution": best.resolution.toString(),
          "seeders": best.result.seeders,
        },
      );
      expect(
        best.result.sizeBytes,
        greaterThan(0),
        reason: "$label: matched result should have a positive size",
      );
      expect(
        best.result.seeders,
        greaterThan(0),
        reason: "$label: matched result should have seeders (zero-seeder results are filtered)",
      );
    }

    test(
      "matches Your Name movie",
      () => expectMovieMatch(21519, "Your Name"),
    );
  });

  group("matchEpisodes", () {
    Future<void> expectEpisodeMatches(
      int anilistId,
      String label,
      List<int> episodeNumbers,
    ) async {
      final anime = await anilistClient.getAnimeById(anilistId);
      expect(
        anime,
        isNotNull,
        reason: "$label: AniList ID $anilistId should exist",
      );
      final episodeMatches = await matcher.matchEpisodes(
        anime!,
        params,
        episodeNumbers: episodeNumbers,
      );
      expect(
        episodeMatches.length,
        equals(episodeNumbers.length),
        reason: "$label: should return a match group for every requested episode",
      );

      for (final epMatch in episodeMatches) {
        _log.infoWithMetadata(
          "Episode ${epMatch.episodeNumber} matches for $label",
          metadata: {
            "anilistTitle": anime.title.display,
            "matchCount": epMatch.matches.length,
            "topFilename":
                epMatch.matches.isNotEmpty
                    ? epMatch.matches.first.result.filename
                    : null,
            "topScore":
                epMatch.matches.isNotEmpty ? epMatch.matches.first.score : null,
          },
        );
        expect(
          epMatch.matches,
          isNotEmpty,
          reason:
              "$label: episode ${epMatch.episodeNumber} should have at least one match",
        );
        // Scores should be sorted descending.
        for (var i = 0; i < epMatch.matches.length - 1; i++) {
          expect(
            epMatch.matches[i].score,
            greaterThanOrEqualTo(epMatch.matches[i + 1].score),
            reason:
                "$label: episode ${epMatch.episodeNumber} matches should be sorted by score descending",
          );
        }
      }
    }

    test(
      "matches My Hero Academia episodes 1-3",
      () => expectEpisodeMatches(21459, "My Hero Academia", [1, 2, 3]),
      timeout: const Timeout(Duration(minutes: 2)),
    );
    test(
      "matches Attack on Titan episodes 1-3",
      () => expectEpisodeMatches(16498, "Attack on Titan", [1, 2, 3]),
      timeout: const Timeout(Duration(minutes: 2)),
    );
    // SPY x FAMILY has consistently-seeded individual episodes on Nyaa.
    // Death Note individual episodes have 0 seeders on Nyaa so it can't be
    // used to test episode matching.
    test(
      "matches Spy x Family episodes 1-3",
      () => expectEpisodeMatches(140960, "Spy x Family", [1, 2, 3]),
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
