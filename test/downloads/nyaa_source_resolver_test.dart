import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/source_resolver/nyaa.dart';
import 'package:senpwai/sources/nyaa.dart' as nyaa;
import 'package:senpwai/sources/shared/matcher/nyaa.dart';
import 'package:senpwai/sources/shared/shared.dart';

void main() {
  group('NyaaDownloadSourceResolver', () {
    test('resolves movies through parsed Nyaa movie matches', () async {
      final resolver = NyaaDownloadSourceResolver(
        matcher: _FakeNyaaMatcher(matches: [_scoredMovieResult()]),
      );

      final result = await resolver.resolve(_movie());

      expect(result.isMatched, isTrue);
      expect(result.result, isTrue);
    });

    test('rejects movies when no parsed Nyaa movie match exists', () async {
      final resolver = NyaaDownloadSourceResolver(
        matcher: _FakeNyaaMatcher(matches: const []),
      );

      final result = await resolver.resolve(_movie());

      expect(result.isFailed, isTrue);
      expect(result.error, 'No movie match found');
    });
  });
}

AnilistAnime _movie() => const AnilistAnime(
  id: 21519,
  title: AnilistTitle(
    romaji: 'Kimi no Na wa.',
    english: 'Your Name.',
    native: '君の名は。',
  ),
  format: AnilistFormat.movie,
  genres: [],
);

ScoredNyaaResult _scoredMovieResult() => ScoredNyaaResult(
  result: nyaa.AnimeResult(
    filename: '[Judas] Kimi no Na wa (Your Name) [BD 1080p] (Movie)',
    torrentFileUrl: 'https://nyaa.si/download/1.torrent',
    magnetUrl: 'magnet:?xt=urn:btih:1',
    sizeBytes: 1024,
    dateAdded: DateTime(2026),
    seeders: 1,
    leechers: 0,
    torrentFileDownloadCount: 1,
  ),
  score: 1,
  resolution: Resolution.res1080p,
  isCompleteSeason: true,
  searchQuery: 'Kimi no Na wa.',
);

class _FakeNyaaMatcher extends NyaaMatcher {
  final List<ScoredNyaaResult> matches;

  _FakeNyaaMatcher({required this.matches});

  @override
  Future<List<ScoredNyaaResult>> matchMovie(
    AnilistAnimeBase<dynamic> anime,
    NyaaMatchParams params,
  ) async {
    return matches;
  }
}
