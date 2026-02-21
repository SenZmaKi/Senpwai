import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/sources/shared/anitomy.dart';
import 'package:senpwai/sources/shared/shared.dart';
import "package:senpwai/shared/log.dart";

void main() {
  setUpAll(setupLogger);
  test('Parse simple anime filename', () {
    const filename = '[SubGroup] Anime Title - 01 [1080p].mkv';
    final parsed = parseFilename(filename);

    expect(parsed.title, 'Anime Title');
    expect(parsed.episode, 1);
    expect(parsed.resolution, Resolution.res1080p);
  });

  test('Parse filename with season and episode', () {
    const filename = 'Series Name S02E15 [720p].mp4';
    final parsed = parseFilename(filename);

    expect(parsed.title, 'Series Name');
    expect(parsed.episode, 15);
    expect(parsed.season, 2);
    expect(parsed.resolution, Resolution.res720p);
  });

  test('Parse complex filename with multiple quality indicators', () {
    const filename = '[HorribleSubs] Sword Art Online - 01 [1080p] 720p.mkv';
    final parsed = parseFilename(filename);

    expect(parsed.title, 'Sword Art Online');
    expect(parsed.episode, 1);
    expect(parsed.resolution, Resolution.res1080p);
  });

  // test("Parse language", () {
  //   const filename = "Attack On Tital 01 (en) Dub.mp4";
  //   final parsed = parseFilename(filename);
  //   expect(parsed.language, Language.english);
  // });

  test('Empty string returns empty result', () {
    final parsed = parseFilename('');
    expect(parsed.title, isNull);
  });

  test('Filename with year', () {
    const filename = 'Anime Title (2023) - 01.mkv';
    final parsed = parseFilename(filename);

    expect(parsed.title, isNotNull);
    expect(parsed.episode, 1);
  });
}
