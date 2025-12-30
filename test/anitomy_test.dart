import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/shared/anitomy.dart';

void main() {
  group('Anitomy FFI Tests', () {
    test('Parse simple anime filename', () {
      const filename = '[SubGroup] Anime Title - 01 [1080p].mkv';
      final elements = parseFilename(filename);

      expect(elements, isNotEmpty);

      // Check for expected element categories
      final categories = elements.map((e) => e.category).toSet();
      expect(categories, contains(ElementCategory.releaseGroup));
      expect(categories, contains(ElementCategory.animeTitle));
      expect(categories, contains(ElementCategory.episodeNumber));
      expect(categories, contains(ElementCategory.videoResolution));
      expect(categories, contains(ElementCategory.fileExtension));
    });

    test('Parse filename with season and episode', () {
      const filename = 'Series Name S02E15 [720p].mp4';
      final elements = parseFilename(filename);

      expect(elements, isNotEmpty);

      final episodeElement = elements.firstWhere(
        (e) => e.category == ElementCategory.episodeNumber,
        orElse: () => throw Exception('Episode not found'),
      );
      expect(episodeElement.value, '15');

      final seasonElement = elements.firstWhere(
        (e) => e.category == ElementCategory.animeSeason,
        orElse: () => throw Exception('Season not found'),
      );
      expect(seasonElement.value, '02'); // Anitomy preserves leading zeros
    });

    test('Empty string returns empty list', () {
      final elements = parseFilename('');
      expect(elements, isEmpty);
    });

    test('Parse complex filename', () {
      const filename = '[HorribleSubs] Sword Art Online - 01 [1080p].mkv';
      final elements = parseFilename(filename);

      expect(elements, isNotEmpty);

      for (final element in elements) {
        print('${element.category}: ${element.value}');
      }
    });
  });
}
