import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/target_path_planner.dart';
import 'package:senpwai/settings/models.dart';

void main() {
  const planner = DownloadTargetPlanner();

  test('planEpisodeFile embeds a zero-padded episode number', () {
    final target = planner.planEpisodeFile(
      directory: '/downloads',
      jobTitle: 'Frieren',
      episodeNumber: 3,
      sourceFileName: 'frieren-03.mkv',
      resolvedUrl: 'https://cdn.example.com/frieren-03.mkv',
    );

    expect(target.directory, '/downloads');
    expect(target.fileName, 'Frieren Episode 03.mkv');
  });

  test('planEpisodeFile keeps no fallback .bin extension', () {
    final target = planner.planEpisodeFile(
      directory: '/downloads',
      jobTitle: 'Frieren',
      episodeNumber: 12,
      sourceFileName: 'frieren-12',
      resolvedUrl: 'https://cdn.example.com/stream/12345',
    );

    expect(target.fileName, 'Frieren Episode 12');
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

  test('resolveAnimeLocation honors custom anime folder override', () async {
    final temp = await Directory.systemTemp.createTemp('senpwai-target-');
    addTearDown(() async => temp.delete(recursive: true));
    final root = Directory('${temp.path}/library');
    final custom = Directory('${temp.path}/custom/Frieren S01');

    final location = await planner.resolveAnimeLocation(
      anime: _anime(english: 'Frieren', romaji: 'Sousou no Frieren'),
      downloadRoots: [root.path],
      customAnimeFolders: [
        CustomAnimeFolder(animeTitle: 'Frieren', folder: custom.path),
      ],
    );

    expect(location.episodeDirectory, custom.path);
  });
}

AnilistAnime _anime({String? english, String? romaji}) => AnilistAnime(
  id: 1,
  title: AnilistTitle(english: english, romaji: romaji),
  genres: const [],
);
