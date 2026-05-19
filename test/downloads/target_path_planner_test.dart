import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/downloads/target_path_planner.dart';

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
}
