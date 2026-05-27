import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/downloads/planners/nyaa.dart';

void main() {
  group('looksLikeVideoFile', () {
    test('accepts common video extensions returned by path.extension', () {
      expect(looksLikeVideoFile('Episode 01.mkv'), isTrue);
      expect(looksLikeVideoFile('/tmp/Season 01/Episode 01.MP4'), isTrue);
      expect(looksLikeVideoFile('movie.webm'), isTrue);
    });

    test('rejects non-video files', () {
      expect(looksLikeVideoFile('subs.ass'), isFalse);
      expect(looksLikeVideoFile('archive.zip'), isFalse);
      expect(looksLikeVideoFile('README'), isFalse);
    });
  });
}
