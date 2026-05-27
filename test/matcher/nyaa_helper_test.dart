import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anitomy/anitomy.dart';
import 'package:senpwai/sources/shared/matcher/nyaa.dart';
import 'package:senpwai/sources/shared/shared.dart';

void main() {
  group('expandNyaaTitleCandidates', () {
    test('adds stripped part and cour variants without duplicates', () {
      final variants = expandNyaaTitleCandidates([
        'SPY x FAMILY Part 2',
        'Frieren Cour 2',
        'Dandadan 2nd Season',
      ]);

      expect(variants, contains('SPY x FAMILY Part 2'));
      expect(variants, contains('SPY x FAMILY'));
      expect(variants, contains('Frieren Cour 2'));
      expect(variants, contains('Frieren'));
      expect(variants, contains('Dandadan 2nd Season'));
      expect(variants, contains('Dandadan'));
      expect(variants.toSet().length, variants.length);
    });
  });

  group('matchesPreferredNyaaLanguage', () {
    test('rejects explicit dub-only releases for Japanese preference', () {
      final parsed = parseFilename(
        '[SomeGroup] Series - 01 [English Dub][1080p].mkv',
      );

      expect(classifyNyaaLanguageSignal(parsed), NyaaLanguageSignal.dubbed);
      expect(matchesPreferredNyaaLanguage(parsed, Language.japanese), isFalse);
      expect(matchesPreferredNyaaLanguage(parsed, Language.english), isTrue);
    });

    test('accepts dual-audio releases for both preferences', () {
      final parsed = parseFilename(
        '[SomeGroup] Series - 01 [1080p][Dual Audio].mkv',
      );

      expect(classifyNyaaLanguageSignal(parsed), NyaaLanguageSignal.dualAudio);
      expect(matchesPreferredNyaaLanguage(parsed, Language.japanese), isTrue);
      expect(matchesPreferredNyaaLanguage(parsed, Language.english), isTrue);
    });

    test('rejects explicit sub-only releases for English preference', () {
      final parsed = parseFilename('[SomeGroup] Series - 01 [Sub][1080p].mkv');

      expect(classifyNyaaLanguageSignal(parsed), NyaaLanguageSignal.subbed);
      expect(matchesPreferredNyaaLanguage(parsed, Language.english), isFalse);
      expect(matchesPreferredNyaaLanguage(parsed, Language.japanese), isTrue);
    });

    test('treats unlabeled releases as unknown instead of assuming audio', () {
      final parsed = parseFilename('[SomeGroup] Series - 01 [1080p].mkv');

      expect(classifyNyaaLanguageSignal(parsed), NyaaLanguageSignal.unknown);
      expect(matchesPreferredNyaaLanguage(parsed, Language.english), isTrue);
      expect(matchesPreferredNyaaLanguage(parsed, Language.japanese), isTrue);
    });
  });
}
