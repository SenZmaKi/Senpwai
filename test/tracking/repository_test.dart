import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/tracking/repository.dart';

void main() {
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
