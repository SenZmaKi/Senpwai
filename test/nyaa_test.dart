import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/sources/nyaa.dart' as nyaa;
import 'package:senpwai/shared/log.dart';

void testParseSearchIncludesTrustedAndRemakeRows() {
  const html = '''
<html>
  <body>
    <table>
      <tbody>
        <tr class="success">
          <td><a title="Anime - English-translated">Anime - English-translated</a></td>
          <td><a href="/view/1">ignored</a><a href="/view/1">[SubsPlease] Tongari Boushi no Atelier - 01 (1080p) [0D8AE311].mkv</a></td>
          <td><a href="/download/1.torrent">torrent</a><a href="magnet:?xt=urn:btih:1">magnet</a></td>
          <td>1.3 GiB</td>
          <td data-timestamp="1712412136">date</td>
          <td>1013</td>
          <td>4</td>
          <td>31248</td>
        </tr>
        <tr class="danger">
          <td><a title="Anime - English-translated">Anime - English-translated</a></td>
          <td><a href="/view/2">ignored</a><a href="/view/2">[ASW] Tongari Boushi no Atelier - 01 [1080p HEVC x265 10Bit][AAC]</a></td>
          <td><a href="/download/2.torrent">torrent</a><a href="magnet:?xt=urn:btih:2">magnet</a></td>
          <td>363.1 MiB</td>
          <td data-timestamp="1712412030">date</td>
          <td>213</td>
          <td>0</td>
          <td>7426</td>
        </tr>
      </tbody>
    </table>
  </body>
</html>
''';

  final results = nyaa.parseSearchResultsHtml(html);

  expect(results, hasLength(2));
  expect(results.first.filename, contains('Tongari Boushi no Atelier - 01'));
  expect(results.first.seeders, 1013);
  expect(results.last.filename, contains('[ASW]'));
  expect(results.last.torrentFileUrl, 'https://nyaa.si/download/2.torrent');
}

Future<void> testSearch() async {
  final source = nyaa.Source.getInstance();
  final results = await source.search(
    params: nyaa.SearchParams(term: "My Hero Academia", page: 1),
  );

  expect(results.items.length, greaterThan(0));
  expect(results.currentPage, 1);
  expect(results.perPage, nyaa.Constants.resultsPerPage);

  // Verify results have required fields
  final firstResult = results.items.first;
  expect(firstResult.filename, isNotEmpty);
  expect(firstResult.torrentFileUrl, isNotEmpty);
  expect(firstResult.magnetUrl, isNotEmpty);
  expect(firstResult.sizeBytes, greaterThan(0));
  expect(firstResult.seeders, greaterThanOrEqualTo(0));
  expect(firstResult.leechers, greaterThanOrEqualTo(0));
  expect(firstResult.torrentFileDownloadCount, greaterThanOrEqualTo(0));
}

Future<void> testSearchPagination() async {
  final source = nyaa.Source.getInstance();
  final results = await source.search(
    params: nyaa.SearchParams(term: "My Hero Academia", page: 1),
  );

  expect(results.items.length, greaterThan(0));
  expect(results.fetchNextPage, isNotNull);

  final results2 = await results.fetchNextPage!();
  expect(results2.items.length, greaterThan(0));
  expect(results2.currentPage, results.currentPage + 1);
}

Future<void> testSearchNoResults() async {
  final source = nyaa.Source.getInstance();
  final results = await source.search(
    params: nyaa.SearchParams(term: "xyznonexistentanimexyz12345", page: 1),
  );

  // Should return empty list, not throw
  expect(results.items.length, 0);
}

void main() {
  setUpAll(setupLogger);

  test(
    "nyaa.parseSearchIncludesTrustedAndRemakeRows",
    testParseSearchIncludesTrustedAndRemakeRows,
  );
  test("nyaa.search", testSearch);
  test("nyaa.searchPagination", testSearchPagination);
  test("nyaa.searchNoResults", testSearchNoResults);
}
