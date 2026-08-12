import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/target_path_planner.dart';
import 'package:senpwai/settings/models.dart';

void main() {
  const planner = DownloadTargetPlanner();

  test('planEpisodeFile embeds an abbreviated zero-padded episode number', () {
    final target = planner.planEpisodeFile(
      directory: '/downloads',
      jobTitle: 'Frieren',
      episodeNumber: 3,
      sourceFileName: 'frieren-03.mkv',
      resolvedUrl: 'https://cdn.example.com/frieren-03.mkv',
    );

    expect(target.directory, '/downloads');
    expect(target.fileName, 'Frieren E03.mkv');
  });

  test('planEpisodeFile keeps no fallback .bin extension', () {
    final target = planner.planEpisodeFile(
      directory: '/downloads',
      jobTitle: 'Frieren',
      episodeNumber: 12,
      sourceFileName: 'frieren-12',
      resolvedUrl: 'https://cdn.example.com/stream/12345',
    );

    expect(target.fileName, 'Frieren E12');
  });

  test('planEpisodeFile uses the server-suggested filename extension', () {
    final target = planner.planEpisodeFile(
      directory: '/downloads',
      jobTitle: 'Frieren',
      episodeNumber: 12,
      sourceFileName: '720p · 180 MB',
      resolvedUrl: 'https://cdn.example.com/download/12345',
      suggestedFileName: 'frieren-12.mp4',
    );

    expect(target.fileName, 'Frieren E12.mp4');
  });

  test('planEpisodeFile falls back to the video content type', () {
    final target = planner.planEpisodeFile(
      directory: '/downloads',
      jobTitle: 'Frieren',
      episodeNumber: 12,
      sourceFileName: '720p · 180 MB',
      resolvedUrl: 'https://cdn.example.com/download/12345',
      contentType: 'video/mp4; charset=binary',
    );

    expect(target.fileName, 'Frieren E12.mp4');
  });

  test('planMovieFile does not add an episode label', () {
    final target = planner.planMovieFile(
      directory: '/downloads',
      jobTitle: 'Your Name',
      sourceFileName: 'movie.mkv',
      resolvedUrl: 'https://cdn.example.com/movie.mkv',
    );

    expect(target.directory, '/downloads');
    expect(target.fileName, 'Your Name.mkv');
  });

  test('resolveAnimeLocation searches configured roots in order', () async {
    final temp = await Directory.systemTemp.createTemp('senpwai-target-');
    addTearDown(() async => temp.delete(recursive: true));
    final firstRoot = Directory('${temp.path}/first');
    final secondRoot = Directory('${temp.path}/second');
    final existing = Directory('${secondRoot.path}/Frieren');
    await existing.create(recursive: true);

    final location = await planner.resolveAnimeLocation(
      anime: _anime(english: 'Frieren', romaji: 'Sousou no Frieren'),
      downloadRoots: [firstRoot.path, secondRoot.path],
    );

    expect(location.episodeDirectory, existing.path);
    expect(location.rootDirectory, secondRoot.path);
  });

  test('resolveAnimeLocation picks existing season folder', () async {
    final temp = await Directory.systemTemp.createTemp('senpwai-target-');
    addTearDown(() async => temp.delete(recursive: true));
    final root = Directory('${temp.path}/library');
    final season = Directory('${root.path}/Attack on Titan/Season 02');
    await season.create(recursive: true);

    final location = await planner.resolveAnimeLocation(
      anime: _anime(romaji: 'Attack on Titan Season 2'),
      downloadRoots: [root.path],
    );

    expect(location.episodeDirectory, season.path);
  });

  test('season file title is stable before and after folders exist', () async {
    final temp = await Directory.systemTemp.createTemp('senpwai-target-');
    addTearDown(() async => temp.delete(recursive: true));
    final root = Directory('${temp.path}/library')..createSync();
    final anime = _anime(english: 'Grand Blue Dreaming Season 3');

    final initial = await planner.resolveAnimeLocation(
      anime: anime,
      downloadRoots: [root.path],
    );
    expect(initial.seriesTitle, 'Grand Blue Dreaming');
    expect(initial.fileTitle, 'Grand Blue Dreaming');
    expect(initial.fileSeasonNumber, 3);
    expect(
      initial.episodeDirectory,
      '${root.path}/Grand Blue Dreaming/Season 03',
    );

    await Directory(initial.episodeDirectory).create(recursive: true);
    final existing = await planner.resolveAnimeLocation(
      anime: anime,
      downloadRoots: [root.path],
    );
    expect(existing.fileTitle, initial.fileTitle);

    final target = planner.planEpisodeFile(
      directory: existing.episodeDirectory,
      jobTitle: existing.fileTitle,
      episodeNumber: 1,
      seasonNumber: existing.fileSeasonNumber,
      sourceFileName: 'episode.mp4',
      resolvedUrl: 'https://cdn.example.com/episode.mp4',
    );
    expect(target.fileName, 'Grand Blue Dreaming S03E01.mp4');
  });

  test('resolveAnimeLocation honors custom anime folder override', () async {
    final temp = await Directory.systemTemp.createTemp('senpwai-target-');
    addTearDown(() async => temp.delete(recursive: true));
    final root = Directory('${temp.path}/library');
    final custom = Directory('${temp.path}/custom/Grand Blue S03')
      ..createSync(recursive: true);

    final location = await planner.resolveAnimeLocation(
      anime: _anime(english: 'Grand Blue Dreaming Season 3'),
      downloadRoots: [root.path],
      customAnimeFolders: [
        CustomAnimeFolder(
          animeTitle: 'Grand Blue Dreaming Season 3',
          folder: custom.path,
        ),
      ],
    );

    expect(location.episodeDirectory, custom.path);
    expect(location.fileTitle, 'Grand Blue Dreaming');
    expect(location.fileSeasonNumber, 3);
  });

  test(
    'direct folder aliases do not replace canonical file identity',
    () async {
      final temp = await Directory.systemTemp.createTemp('senpwai-target-');
      addTearDown(() async => temp.delete(recursive: true));
      final root = Directory('${temp.path}/library')..createSync();
      final direct = Directory('${root.path}/Grand Blue Dreaming Season 3')
        ..createSync();

      final location = await planner.resolveAnimeLocation(
        anime: _anime(english: 'Grand Blue Dreaming Season 3'),
        downloadRoots: [root.path],
      );

      expect(location.episodeDirectory, direct.path);
      expect(location.fileTitle, 'Grand Blue Dreaming');
      expect(location.fileSeasonNumber, 3);
    },
  );
}

AnilistAnime _anime({String? english, String? romaji}) => AnilistAnime(
  id: 1,
  title: AnilistTitle(english: english, romaji: romaji),
  genres: const [],
);
