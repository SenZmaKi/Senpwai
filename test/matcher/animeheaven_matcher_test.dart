@Tags(['network'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/sources/shared/matcher/animeheaven.dart';
import 'package:senpwai/sources/shared/shared.dart' as shared;

import '../support/support.dart';

final _log = Logger("senpwai.sources.matcher.animeheaven.test");

void main() {
  late AnilistUnauthenticatedClient anilistClient;
  late AnimeheavenMatcher matcher;

  setUpAll(() async {
    await setupTestApp();
    anilistClient = AnilistUnauthenticatedClient();
    matcher = AnimeheavenMatcher();
  });

  Future<void> expectMatch(int anilistId, String expectedTitle) async {
    final anime = await anilistClient.getAnimeById(anilistId);
    expect(anime, isNotNull, reason: "AniList ID $anilistId should exist");
    final matches = await matcher.match(anime!);
    expect(matches, isNotEmpty, reason: "$expectedTitle: should find matches");
    final best = matches.first;
    _log.infoWithMetadata(
      "Best AnimeHeaven match for $expectedTitle",
      metadata: {
        "anilistTitle": anime.title.display,
        "matchedTitle": best.result.title,
        "alternativeTitles": best.result.alternativeTitles,
        "url": best.result.url,
        "score": best.score,
      },
    );
    expect(best.result.title, expectedTitle);
    expect(best.score, greaterThanOrEqualTo(shared.Constants.minMatchScore));
  }

  // TV series, including picking the base entry over sequels and spin-offs.
  test(
    "matches Frieren",
    () => expectMatch(154587, "Frieren: Beyond Journey's End"),
  );
  test("matches One Piece", () => expectMatch(21, "One Piece"));
  test(
    "matches Demon Slayer",
    () => expectMatch(101922, "Demon Slayer: Kimetsu no Yaiba"),
  );
  test("matches Attack on Titan", () => expectMatch(16498, "Attack on Titan"));

  // Sequels must not collapse onto the first season.
  test(
    "matches Re:Zero Season 2",
    () =>
        expectMatch(108632, "Re:ZERO: Starting Life in Another World Season 2"),
  );
  test(
    "matches Mob Psycho 100 II",
    () => expectMatch(101338, "Mob Psycho 100 II"),
  );

  // Punctuation-heavy titles.
  test("matches Steins;Gate", () => expectMatch(9253, "Steins;Gate"));
  test("matches Oshi no Ko", () => expectMatch(150672, "[Oshi no Ko]"));
  test("matches Spy x Family", () => expectMatch(140960, "SPY x FAMILY"));

  // Movies.
  test("matches Your Name", () => expectMatch(21519, "your name."));

  // AnimeHeaven titles that only match through the anime page's romaji title.
  test(
    "matches Jujutsu Kaisen listed as Sorcery Fight",
    () => expectMatch(113415, "Sorcery Fight"),
  );
  test(
    "matches Oregairu listed as My Teen Romantic Comedy SNAFU",
    () => expectMatch(14813, "My Teen Romantic Comedy SNAFU"),
  );
}
