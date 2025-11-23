import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anime/scrapers/animepahe.dart';
import 'package:senpwai/shared/log.dart';

Future<void> testSearch() async {
  final scraper = AnimepaheScraper();
  final results = await scraper.search(
    options: SearchOptions(keyword: "one piece"),
  );
  expect(results.items.length, greaterThan(0));
  if (results.nextPage != null) {
    final results2 = await results.nextPage!();
    expect(results2.items.length, greaterThan(0));
  }
}

void main() {
  setUpAll(setupLogger);

  test("animepahe.search", testSearch);
}
