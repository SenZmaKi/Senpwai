import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/anime/sources/animepahe.dart' as animepahe;
import 'package:senpwai/shared/log.dart';

final log = Logger("senpwai.anime.sources.animepahe.test");

Future<animepahe.AnimeResult> testSearch({animepahe.Source? source}) async {
  source ??= animepahe.Source();
  final results = await source.search(
    params: animepahe.SearchParams(term: "one piece"),
  );
  expect(results.items.length, greaterThan(0));
  if (results.fetchNextPage != null) {
    final results2 = await results.fetchNextPage!();
    expect(results2.items.length, greaterThan(0));
  }
  return results.items.first;
}

Future<void> testFetchEpisodeListPageJson() async {
  final source = animepahe.Source();
  final result = await testSearch(source: source);
  final json = await source.fetchEpisodeListPageJson(
    animeId: result.session,
    pageNum: 1,
  );
  expect(json["data"], isNotNull);
  expect(json["per_page"], isNotNull);
}

Future<void> testComputeEpisodePageRange() async {
  final source = animepahe.Source();
  final result = await testSearch(source: source);
  final info = await source.computeEpisodePageRange(
    startEpisode: 1,
    endEpisode: 10,
    animeId: result.session,
  );
  log.info(info.toString());
  expect(info.firstPageJson["data"], isNotNull);
  expect(info.firstPageJson["per_page"], isNotNull);
}

Future<List<animepahe.EpisodeSession>> testFetchEpisodeSessions({
  animepahe.AnimeResult? result,
  animepahe.Source? source,
}) async {
  source ??= animepahe.Source();
  result ??= await testSearch(source: source);
  final sessions = await source.fetchEpisodeSessions(
    animeId: result.session,
    pageNum: 1,
  );
  expect(sessions.length, greaterThan(0));
  return sessions;
}

Future<void> testFindEpisodeSessionsWithinRange() async {
  final source = animepahe.Source();
  final result = await testSearch(source: source);
  final sessions = await testFetchEpisodeSessions(source: source);
  const endEpisode = 10;
  final pages = source.findEpisodeSessionsWithinRange(
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
  test("animepahe.fetchEpisodeListPageJson", testFetchEpisodeListPageJson);
  test("animepahe.computeEpisodePageRange", testComputeEpisodePageRange);
  test("animepahe.fetchEpisodeSessions", testFetchEpisodeSessions);
  test(
    "animepahe.findEpisodeSessionsWithinRange",
    testFindEpisodeSessionsWithinRange,
  );
}
