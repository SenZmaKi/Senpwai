import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/sources/animepahe.dart' as animepahe;
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/sources/shared/shared.dart';

final log = Logger("senpwai.anime.sources.animepahe.test");

Future<List<animepahe.AnimeResult>> testSearch() async {
  final source = animepahe.Source();
  final results = await source.search(
    params: animepahe.SearchParams(term: "My Hero Academia"),
  );
  expect(results.items.length, greaterThan(0));
  if (results.fetchNextPage != null) {
    final results2 = await results.fetchNextPage!();
    expect(results2.items.length, greaterThan(0));
  }
  return results.items;
}

Future<void> testFetchEpisodeListPageJson() async {
  final result = (await testSearch()).first;
  final source = animepahe.Source();
  final json = await source.fetchEpisodeListPageJson(
    animeSession: result.session,
    pageNum: 1,
  );
  expect(json["data"], isNotNull);
  expect(json["per_page"], isNotNull);
}

Future<void> testComputeEpisodePageRange() async {
  final result = (await testSearch()).first;
  final source = animepahe.Source();
  final info = await source.computeEpisodePageRange(
    startEpisode: 1,
    endEpisode: 10,
    animeSession: result.session,
  );
  expect(info.firstPageJson["data"], isNotNull);
  expect(info.firstPageJson["per_page"], isNotNull);
}

Future<List<animepahe.EpisodeSession>> testFetchEpisodeSessions() async {
  final result = (await testSearch()).first;
  final source = animepahe.Source();
  final sessions = await source.fetchEpisodeSessions(
    animeSession: result.session,
    pageNum: 1,
  );
  expect(sessions.length, greaterThan(0));
  return sessions;
}

Future<void> testFindEpisodeSessionsWithinRange() async {
  final result = (await testSearch()).first;
  final sessions = await testFetchEpisodeSessions();
  const endEpisode = 10;
  final source = animepahe.Source();
  final pages = source.findEpisodeSessionsWithinRange(
    animeSession: result.session,
    firstEpisode: 1,
    startEpisode: 1,
    endEpisode: endEpisode,
    episodeSessions: sessions,
  );
  expect(pages.length, endEpisode);
}

Future<List<animepahe.DownloadLink>> testFetchDownloadLinks() async {
  final result = (await testSearch()).first;
  final episodeSession = (await testFetchEpisodeSessions()).first;
  final source = animepahe.Source();
  final downloadLinks = await source.fetchDownloadLinks(
    animeTitle: result.title,
    animeSession: result.session,
    episodeSession: episodeSession,
  );
  expect(downloadLinks.length, greaterThan(0));
  return downloadLinks;
}

Future<animepahe.DownloadLink> testFindBestDownloadLinkMatch({
  Resolution resolution = Resolution.res720p,
  Language audioLanguage = Language.japanese,
}) async {
  final downloadLinks = (await testFetchDownloadLinks());
  final animeTitle = downloadLinks.first.animeTitle;
  final episodeNumber = downloadLinks.first.episodeNumber;
  final source = animepahe.Source();
  final bestMatch = source.findBestDownloadLinkMatch(
    animeTitle: animeTitle,
    episodeNumber: episodeNumber,
    resolution: resolution,
    audioLanguage: audioLanguage,
    downloadLinks: downloadLinks,
  );
  expect(bestMatch.audioLanguage == audioLanguage, true);
  expect(bestMatch.resolution == resolution, true);
  return bestMatch;
}

Future<void> testFetchDirectDownloadLink({
  Resolution resolution = Resolution.res720p,
  Language audioLanguage = Language.japanese,
}) async {
  final bestDownloadLinkMatch = await testFindBestDownloadLinkMatch(
    resolution: resolution,
  );
  final source = animepahe.Source();
  final directDownloadLink = await source.fetchDirectDownloadLink(
    downloadLink: bestDownloadLinkMatch,
  );
  expect(directDownloadLink.url, isNotEmpty);
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
  test("animepahe.fetchDownloadLinks", testFetchDownloadLinks);

  test("animepahe.findBestDownloadLinkMatch", testFindBestDownloadLinkMatch);
  test("animepahe.fetchDirectDownloadLink", testFetchDirectDownloadLink);
}
