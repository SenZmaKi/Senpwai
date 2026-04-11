import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/sources/shared/matcher.dart';
import 'package:senpwai/sources/shared/matcher.dart' as m;
import 'package:senpwai/shared/log.dart';

final _log = Logger("senpwai.sources.matcher.tokyoinsider.test");

void main() {
  late AnilistUnauthenticatedClient anilistClient;
  late TokyoinsiderMatcher matcher;

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    setupLogger();
    anilistClient = AnilistUnauthenticatedClient();
    matcher = TokyoinsiderMatcher();
  });

  Future<void> expectMatch(int anilistId, String label) async {
    final anime = await anilistClient.getAnimeById(anilistId);
    expect(anime, isNotNull, reason: "$label: AniList ID $anilistId should exist");
    final matches = await matcher.match(anime!);
    expect(matches, isNotEmpty, reason: "$label: should find TokyoInsider matches");
    final best = matches.first;
    _log.infoWithMetadata(
      "Best TokyoInsider match for $label",
      metadata: {
        "anilistTitle": anime.title.display,
        "matchedTitle": best.result.title,
        "url": best.result.url,
        "score": best.score,
      },
    );
    expect(
      best.score,
      greaterThan(m.Constants.minPerfectMatchScore),
      reason: "$label: score ${best.score} should exceed ${m.Constants.minPerfectMatchScore}",
    );
  }

  // TV series — popular, varied genres
  test("matches My Hero Academia (TV)", () => expectMatch(21459, "My Hero Academia"));
  test("matches Attack on Titan (TV)", () => expectMatch(16498, "Attack on Titan"));
  test("matches Death Note (TV)", () => expectMatch(1535, "Death Note"));
  test("matches Steins;Gate (TV)", () => expectMatch(9253, "Steins;Gate"));
  test("matches Mob Psycho 100 (TV)", () => expectMatch(21507, "Mob Psycho 100"));
  test("matches Jujutsu Kaisen (TV)", () => expectMatch(113415, "Jujutsu Kaisen"));
  test("matches Demon Slayer (TV)", () => expectMatch(101922, "Demon Slayer"));

  // Movies
  test("matches Your Name (Movie)", () => expectMatch(21519, "Your Name"));
  test("matches Spirited Away (Movie)", () => expectMatch(199, "Spirited Away"));
  test("matches A Silent Voice (Movie)", () => expectMatch(20954, "A Silent Voice"));

  // Sequel with similar title to original
  test("matches Attack on Titan Season 2 (sequel)", () => expectMatch(20958, "Attack on Titan Season 2"));

  // Long/complex titles with special characters
  test("matches Re:Zero (long title)", () => expectMatch(21355, "Re:Zero"));
  test("matches Oregairu (abbreviated title)", () => expectMatch(14813, "Oregairu"));
}
