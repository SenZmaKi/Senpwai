@Tags(['network'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/shared/net/download/download.dart';
import 'package:senpwai/sources/animeheaven.dart' as animeheaven;

import 'support/support.dart';

const _frierenUrl = 'https://animeheaven.me/anime.php?ak2gr';

void main() {
  setUpAll(setupTestApp);

  test('animeheaven.search', () async {
    final results = await animeheaven.Source.getInstance().search(
      term: 'Sousou no Frieren',
    );

    expect(
      results.map((result) => result.url),
      contains(_frierenUrl),
      reason: 'AnimeHeaven search should match romaji titles',
    );
  });

  test('animeheaven.fetchEpisodePages', () async {
    final pages = await animeheaven.Source.getInstance().fetchEpisodePages(
      animeUrl: _frierenUrl,
      animeTitle: "Frieren: Beyond Journey's End",
    );

    expect(
      pages.map((page) => page.episodeNumber).toSet(),
      containsAll([for (var episode = 1; episode <= 28; episode++) episode]),
    );
  });

  test('animeheaven.fetchEpisodePages skips fractional recap rows', () async {
    final pages = await animeheaven.Source.getInstance().fetchEpisodePages(
      animeUrl: 'https://animeheaven.me/anime.php?1ht8d',
      animeTitle: 'One Piece',
    );

    expect(pages.map((page) => page.episodeNumber), contains(1));
    expect(pages.length, greaterThan(100));
  });

  test('animeheaven.fetchDownloadUrl resolves a downloadable file', () async {
    final source = animeheaven.Source.getInstance();
    final pages = await source.fetchEpisodePages(
      animeUrl: _frierenUrl,
      animeTitle: "Frieren: Beyond Journey's End",
    );
    final episode = pages.firstWhere((page) => page.episodeNumber == 8);

    final url = await source.fetchDownloadUrl(episodePage: episode);
    final target = await Download.probeSingleFile(url: url);

    expect(Uri.parse(url).host, endsWith('animeheaven.me'));
    expect(target.supportsRangeRequests, isTrue);
    expect(target.sizeBytes, greaterThan(50 * 1024 * 1024));
    expect(target.suggestedFileName, contains('Sousou no Frieren'));
    expect(target.suggestedFileName, contains('- 08'));
  });
}
