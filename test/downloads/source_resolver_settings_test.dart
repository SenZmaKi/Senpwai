import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/source_resolver.dart';
import 'package:senpwai/downloads/source_resolver/nyaa.dart';
import 'package:senpwai/settings/settings.dart';

void main() {
  test('source resolver honors enabled sources and priority', () async {
    final resolver = DownloadSourceResolver(
      settings: const SourcePreferences(
        enabledSources: {AnimeSource.nyaa},
        priority: [AnimeSource.animepahe, AnimeSource.nyaa],
      ),
      nyaaResolver: _FakeNyaaResolver(),
    );

    final matches = await resolver.resolveAll(_anime());
    final preferred = resolver.selectPreferredSource(
      matches: matches,
      sourceSelectedByUser: false,
      selectedSource: null,
    );

    expect(matches.animepaheMatch.isFailed, isTrue);
    expect(preferred, AnimeSource.nyaa);
  });
}

AnilistAnime _anime() => const AnilistAnime(
  id: 1,
  title: AnilistTitle(romaji: 'Test'),
  genres: [],
);

class _FakeNyaaResolver extends NyaaDownloadSourceResolver {
  @override
  Future<SourceMatchState<bool>> resolve(
    AnilistAnimeBase<dynamic> anime,
  ) async {
    return const SourceMatchState.matched(true);
  }
}
