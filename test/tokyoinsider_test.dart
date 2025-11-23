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

void main() {
  setUpAll(setupLogger);

  test("tokyoinsider.search", testSearch);
}
