import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anime/scrapers/animepahe.dart';
import 'package:senpwai/shared/log.dart';

final log = Logger("senpwai.anime.scrapers.animepahe.test");

Future<SearchResult> testSearch({AnimepaheScraper? scraper}) async {
  scraper ??= AnimepaheScraper();
  final results = await scraper.search(
    options: SearchOptions(keyword: "one piece"),
  );
  expect(results.items.length, greaterThan(0));
  if (results.nextPage != null) {
    final results2 = await results.nextPage!();
    expect(results2.items.length, greaterThan(0));
  }
  return results.items.first;
}

Future<void> testGetEpisodeListPagesJson() async {
  final scraper = AnimepaheScraper();
  final result = await testSearch(scraper: scraper);
  final json = await scraper.getEpisodeListPagesJson(
    animeId: result.session,
    pageNum: 1,
  );
  expect(json["data"], isNotNull);
  expect(json["per_page"], isNotNull);
}

Future<void> testCalculateEpisodeListPagesInfo() async {
  final scraper = AnimepaheScraper();
  final result = await testSearch(scraper: scraper);
  final info = await scraper.calculateEpisodeListPagesInfo(
    startEpisode: 1,
    endEpisode: 10,
    animeId: result.session,
  );
  log.info(info.toString());
  expect(info.firstPageJson["data"], isNotNull);
  expect(info.firstPageJson["per_page"], isNotNull);
}

Future<List<EpisodeSession>> testGetEpisodeListPageSessions({
  SearchResult? result,
  AnimepaheScraper? scraper,
}) async {
  scraper ??= AnimepaheScraper();
  result ??= await testSearch(scraper: scraper);
  final sessions = await scraper.getEpisodeListPageSessions(
    animeId: result.session,
    pageNum: 1,
  );
  expect(sessions.length, greaterThan(0));
  return sessions;
}

Future<void> testGenerateEpisodePages() async {
  final scraper = AnimepaheScraper();
  final result = await testSearch(scraper: scraper);
  final sessions = await testGetEpisodeListPageSessions(scraper: scraper);
  const endEpisode = 10;
  final pages = scraper.generateEpisodePages(
    animeId: result.session,
    firstEpisode: 1,
    startEpisode: 1,
    endEpisode: endEpisode,
    episodeSessions: sessions,
  );
  expect(pages.length, endEpisode);
}

void main() {
  setUpAll(setupLogger);

  test("animepahe.search", testSearch);
  test("animepahe.getEpisodeListPagesJson", testGetEpisodeListPagesJson);
  test(
    "animepahe.calculateEpisodeListPagesInfo",
    testCalculateEpisodeListPagesInfo,
  );
  test("animepahe.getEpisodeListPageSessions", testGetEpisodeListPageSessions);
  test("animepahe.generateEpisodePages", testGenerateEpisodePages);
}
