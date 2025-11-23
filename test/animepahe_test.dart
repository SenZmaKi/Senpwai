import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anime/scrapers/animepahe.dart';
import 'package:senpwai/shared/log.dart';

Future<void> testSearch() async {
  final scraper = AnimepaheScraper();
  final result = await scraper.search(
    options: SearchOptions(keyword: "one piece"),
  );
  if (result.nextPage != null) {
    await result.nextPage!();
  }
}

void main() {
  setUpAll(setupLogger);

  test("animepahe.search", testSearch);
}
