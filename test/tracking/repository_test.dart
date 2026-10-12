import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/tracking/repository.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/sources/shared/shared.dart';

void main() {
  test('concurrent saves remain readable and recover the backup', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tracked-concurrency-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/tracked.json');
    final repository = TrackingRepository(file: file);
    await Future.wait(List.generate(30, (_) => repository.save([])));
    expect(await repository.load(), isEmpty);
    await repository.save([]);
    await file.writeAsString('broken json');
    expect(await repository.load(), isEmpty);
    expect(await File('${file.path}.bak').exists(), isTrue);
  });

  test('loads tracked anime snapshots saved with ISO date strings', () async {
    final directory = await Directory.systemTemp.createTemp(
      'senpwai-tracking-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/tracked_anime.json');
    await file.writeAsString('''
{
  "trackedAnime": [
    {
      "anilistId": 1,
      "animeSnapshot": {
        "id": 1,
        "title": {"romaji": "Example"},
        "genres": [],
        "episode": 3,
        "nextEpisodeAiring": "2026-08-14T12:00:00.000Z",
        "startDate": "2026-01-01T00:00:00.000Z",
        "endDate": "2026-03-01T00:00:00.000Z"
      },
      "resolution": "res1080p",
      "language": "japanese",
      "downloadFolder": "C:/downloads",
      "createdAt": "2026-01-01T00:00:00.000Z",
      "updatedAt": "2026-01-01T00:00:00.000Z"
    }
  ]
}
''');

    final trackedAnime = await TrackingRepository(file: file).load();

    expect(trackedAnime, hasLength(1));
    final locked = trackedAnime.single.copyWith(
      preferredSource: AnimeSource.nyaa,
      sourceSelectedByUser: true,
    );
    final repository = TrackingRepository(file: file);
    await repository.save([locked]);
    final restored = (await repository.load()).single;
    expect(restored.preferredSource, AnimeSource.nyaa);
    expect(restored.sourceSelectedByUser, isTrue);
    await repository.save([
      restored.copyWith(
        resolution: Resolution.res720p,
        language: Language.english,
      ),
    ]);
    final customized = (await repository.load()).single;
    expect(customized.resolution, Resolution.res720p);
    expect(customized.language, Language.english);
    expect(customized.preferredSource, AnimeSource.nyaa);
    expect(customized.downloadFolder, restored.downloadFolder);
    final automatic = restored.copyWith(clearPreferredSource: true);
    await repository.save([automatic]);
    final unlocked = (await repository.load()).single;
    expect(unlocked.preferredSource, isNull);
    expect(unlocked.sourceSelectedByUser, isFalse);

    expect(trackedAnime.single.animeSnapshot.episode, 3);
    expect(
      trackedAnime.single.animeSnapshot.nextEpisodeAiring,
      DateTime.parse('2026-08-14T12:00:00.000Z'),
    );
    expect(
      trackedAnime.single.animeSnapshot.startDate,
      DateTime.parse('2026-01-01T00:00:00.000Z'),
    );
  });
}
