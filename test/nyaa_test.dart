import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/sources/nyaa.dart' as nyaa;
import 'package:senpwai/shared/log.dart';

Future<void> testSearch() async {
  final source = nyaa.Source();
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
  final source = nyaa.Source();
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
  final source = nyaa.Source();
  final results = await source.search(
    params: nyaa.SearchParams(term: "xyznonexistentanimexyz12345", page: 1),
  );

  // Should return empty list, not throw
  expect(results.items.length, 0);
}

void main() {
  setUpAll(setupLogger);

  test("nyaa.search", testSearch);
  test("nyaa.searchPagination", testSearchPagination);
  test("nyaa.searchNoResults", testSearchNoResults);
}
