import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anilist/enums.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/planners/animeheaven.dart';
import 'package:senpwai/sources/animeheaven.dart' as animeheaven;
import 'package:senpwai/sources/shared/shared.dart';

import '../support/support.dart';

void main() {
  setUpAll(setupTestApp);

  test('unsupported audio is rejected before querying AnimeHeaven', () async {
    final request = DownloadRequest(
      anime: const AnilistAnime(
        id: 1,
        title: AnilistTitle(romaji: 'Show'),
        format: AnilistFormat.tv,
        genres: [],
      ),
      source: AnimeSource.animeheaven,
      startEpisode: 1,
      endEpisode: 1,
      downloadFolder: '/tmp',
      fileTitle: 'Show',
      resolution: Resolution.res720p,
      language: Language.english,
      allowAudioFallback: false,
    );

    await expectLater(
      AnimeHeavenDownloadPlanner().plan(
        request: request,
        animeMatch: const animeheaven.AnimeResult(
          title: 'Show',
          url: 'https://example.com/show',
        ),
      ),
      throwsA(
        isA<DownloadUserError>()
            .having(
              (error) => error.title,
              'title',
              'Requested audio unavailable',
            )
            .having(
              (error) => error.description,
              'description',
              contains('Select Japanese audio or enable audio fallback'),
            ),
      ),
    );
  });
}
