import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/sources/tokyoinsider.dart' as tokyoinsider;
import 'package:senpwai/shared/log.dart';

Future<void> testSearch() async {
  final source = tokyoinsider.Source();
  final results = await source.search(
    params: tokyoinsider.SearchParams(term: "My Hero Academia"),
  );

  expect(results.length, greaterThan(0));
}

Future<void> testFetchEpisodePages() async {
  final source = tokyoinsider.Source();
  final episodePages = await source.fetchEpisodePages(
    animeUrl:
        "https://www.tokyoinsider.com/anime/B/Boku_no_Hero_Academia_2nd_Season_(TV)",
    animeTitle: "Boku no Hero Academia 2nd Season",
  );
  expect(episodePages.length, greaterThan(0));
}

Future<void> testFetchEpisodeDownloadLinks() async {
  final episodePage = tokyoinsider.EpisodePage(
    animeTitle: "Boku no Hero Academia 2nd Season",
    title: "Boku no Hero Academia 2nd Season episode 25",
    url:
        "https://www.tokyoinsider.com/anime/B/Boku_no_Hero_Academia_2nd_Season_(TV)/episode/25",
  );
  final source = tokyoinsider.Source();
  final episodeDownloadLinks = await source.fetchEpisodeDownloadLinks(
    episodePage: episodePage,
  );
  expect(episodeDownloadLinks.length, greaterThan(0));
}

void main() {
  setUpAll(setupLogger);

  test("tokyoinsider.search", testSearch);
  test("tokyoinsider.fetchEpisodePages", testFetchEpisodePages);
  test("tokyoinsider.fetchEpisodeDownloadLinks", testFetchEpisodeDownloadLinks);
}
