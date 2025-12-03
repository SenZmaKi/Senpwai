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

Future<void> testGetEpisodePages() async {
  final animeUrl =
      "https://www.tokyoinsider.com/anime/B/Boku_no_Hero_Academia_2nd_Season_(TV)";
  final scraper = TokyoInsiderScraper();
  final episodePages = await scraper.getEpisodePages(animeUrl: animeUrl);
  expect(episodePages.length, greaterThan(0));
}

Future<void> testGetEpisodeDownloadLinks() async {
  final episodePage = EpisodePage(
    episodeTitle: "Boku no Hero Academia 2nd Season episode 25",
    url:
        "https://www.tokyoinsider.com/anime/B/Boku_no_Hero_Academia_2nd_Season_(TV)/episode/25",
  );
  final scraper = TokyoInsiderScraper();
  final episodeDownloadLinks = await scraper.getEpisodeDownloadLinks(
    episodePage: episodePage,
  );
  expect(episodeDownloadLinks.length, greaterThan(0));
}

void main() {
  setUpAll(setupLogger);

  test("tokyoinsider.search", testSearch);
  test("tokyoinsider.getEpisodePages", testGetEpisodePages);
  test("tokyoinsider.getEpisodeDownloadLinks", testGetEpisodeDownloadLinks);
}
