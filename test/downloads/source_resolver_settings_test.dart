import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/source_resolver.dart';
import 'package:senpwai/downloads/source_resolver/nyaa.dart';
import 'package:senpwai/settings/settings.dart';

import '../support/support.dart';

void main() {
  setUpAll(setupTestApp);

  test('single-source checks query only the selected enabled source', () async {
    final nyaa = _FakeNyaaResolver();
    final resolver = DownloadSourceResolver(
      settings: const SourcePreferences(enabledSources: {AnimeSource.nyaa}),
      nyaaResolver: nyaa,
    );
    expect(
      (await resolver.resolveSource(_anime(), AnimeSource.nyaa)).isMatched,
      isTrue,
    );
    expect(nyaa.calls, 1);
    expect(
      (await resolver.resolveSource(_anime(), AnimeSource.animepahe)).error,
      'Source disabled',
    );
    expect(nyaa.calls, 1);
  });

  test('enabled but unavailable locked source never falls back', () {
    final resolver = DownloadSourceResolver();
    const matches = ResolvedSourceMatches(
      animeheavenMatch: SourceMatchState.failed('No match'),
      animepaheMatch: SourceMatchState.failed('Network unavailable'),
      tokyoinsiderMatch: SourceMatchState.failed('No match'),
      nyaaMatch: SourceMatchState.matched(true),
    );
    expect(
      resolver.selectPreferredSource(
        matches: matches,
        sourceSelectedByUser: true,
        selectedSource: AnimeSource.animepahe,
        lockSelectedSource: true,
      ),
      isNull,
    );
    expect(
      resolver.selectPreferredSource(
        matches: matches,
        sourceSelectedByUser: false,
        selectedSource: AnimeSource.animepahe,
      ),
      AnimeSource.nyaa,
    );
  });

  for (final locked in [false, true]) {
    test('unavailable selected source: locked=$locked', () async {
      final resolver = DownloadSourceResolver(
        settings: const SourcePreferences(
          enabledSources: {AnimeSource.nyaa},
          priority: [AnimeSource.nyaa],
        ),
        nyaaResolver: _FakeNyaaResolver(),
      );
      final matches = await resolver.resolveAll(_anime());
      expect(
        resolver.selectPreferredSource(
          matches: matches,
          sourceSelectedByUser: true,
          selectedSource: AnimeSource.animepahe,
          lockSelectedSource: locked,
        ),
        locked ? isNull : AnimeSource.nyaa,
      );
      expect(
        resolver.selectPreferredSource(
          matches: matches,
          sourceSelectedByUser: true,
          selectedSource: AnimeSource.nyaa,
          lockSelectedSource: true,
        ),
        AnimeSource.nyaa,
      );
    });
  }

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
  int calls = 0;
  @override
  Future<SourceMatchState<bool>> resolve(
    AnilistAnimeBase<dynamic> anime,
  ) async {
    calls++;
    return const SourceMatchState.matched(true);
  }
}
