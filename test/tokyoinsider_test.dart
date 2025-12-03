import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anime/scrapers/tokyoinsider.dart';
import 'package:senpwai/shared/log.dart';

Future<void> testSearch() async {
  final scraper = TokyoInsiderScraper();
  final results = await scraper.search(
    options: SearchOptions(keyword: "one piece"),
  );

  expect(results.length, greaterThan(0));
}

Future<void> testGetEpisodes() async {
  final animeUrl =
      "https://www.tokyoinsider.com/anime/B/Boku_no_Hero_Academia_2nd_Season_(TV)";
  final scraper = TokyoInsiderScraper();
  final episodes = await scraper.getEpisodes(animeUrl: animeUrl);
  print(episodes);
  expect(episodes.length, greaterThan(0));
}

void main() {
  setUpAll(setupLogger);

  test("tokyoinsider.search", testSearch);
  test("tokyoinsider.getEpisodes", testGetEpisodes);
}
