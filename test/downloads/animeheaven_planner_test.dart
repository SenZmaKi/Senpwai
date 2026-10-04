@Tags(['network'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/planners/animeheaven.dart';
import 'package:senpwai/downloads/source_resolver/animeheaven.dart';
import 'package:senpwai/shared/net/download/download.dart';
import 'package:senpwai/shared/net/download/download_dio.dart';
import 'package:senpwai/shared/net/download/download_state.dart';
import 'package:senpwai/shared/net/download/shared.dart';
import 'package:senpwai/shared/net/user_agents.dart';
import 'package:senpwai/sources/animeheaven.dart' as animeheaven;
import 'package:senpwai/sources/shared/shared.dart';

import '../support/support.dart';

const _frierenAnilistId = 154587;

void main() {
  late AnilistAnime frieren;
  late animeheaven.AnimeResult frierenMatch;
  late Directory downloadDirectory;

  setUpAll(() async {
    await setupTestApp();
    frieren = (await AnilistUnauthenticatedClient().getAnimeById(
      _frierenAnilistId,
    ))!;
    final match = await AnimeheavenDownloadSourceResolver().resolve(frieren);
    expect(match.isMatched, isTrue, reason: match.error);
    frierenMatch = match.result!.result;
    downloadDirectory = await Directory.systemTemp.createTemp(
      'senpwai-animeheaven-',
    );
  });

  tearDownAll(() async {
    if (await downloadDirectory.exists()) {
      await downloadDirectory.delete(recursive: true);
    }
  });

  DownloadRequest request(
    List<int> episodes, {
    Resolution resolution = Resolution.res1080p,
    Language language = Language.japanese,
  }) => DownloadRequest(
    anime: frieren,
    source: AnimeSource.animeheaven,
    startEpisode: episodes.first,
    endEpisode: episodes.last,
    episodeNumbers: episodes,
    downloadFolder: downloadDirectory.path,
    fileTitle: 'Frieren',
    resolution: resolution,
    language: language,
  );

  test('plans episodes and reports unavailable quality and audio', () async {
    final batch = await AnimeHeavenDownloadPlanner().plan(
      request: request(
        [8, 9, 999],
        resolution: Resolution.res720p,
        language: Language.english,
      ),
      animeMatch: frierenMatch,
    );

    final jobs = batch.jobs.cast<PreparedHttpDownloadJob>();
    expect(jobs.map((job) => job.episodeNumber), [8, 9]);
    expect(jobs.map((job) => job.fileName), [
      'Frieren E08.mp4',
      'Frieren E09.mp4',
    ]);
    expect(jobs.every((job) => job.source == AnimeSource.animeheaven), isTrue);
    expect(batch.unavailableEpisodeNumbers, [999]);
    expect(batch.notices.map((notice) => notice.title), [
      'Audio fallback',
      'Quality fallback',
    ]);
  });

  test('rejects ranges without any hosted episode', () async {
    await expectLater(
      AnimeHeavenDownloadPlanner().plan(
        request: request([999]),
        animeMatch: frierenMatch,
      ),
      throwsA(
        isA<DownloadUserError>().having(
          (error) => error.title,
          'title',
          'No episodes found',
        ),
      ),
    );
  });

  test(
    'downloads a planned episode end to end',
    timeout: const Timeout(Duration(minutes: 15)),
    () async {
      final batch = await AnimeHeavenDownloadPlanner().plan(
        request: request([1]),
        animeMatch: frierenMatch,
      );
      expect(batch.notices, isEmpty);
      final job = batch.jobs.single as PreparedHttpDownloadJob;

      final download = Download(
        dio: createDownloadDio(userAgent: getRandomUserAgent()),
        params: DownloadParams(
          url: job.resolvedUrl,
          targetFile: File(job.targetFilePath),
          sizeBytes: job.totalBytes,
          numberOfParts: 8,
          headers: job.headers,
        ),
      );
      await download.startAndWait();

      expect(download.state.status, DownloadStatus.completed);
      final file = File(job.targetFilePath);
      expect(await file.length(), job.totalBytes);
      final header = await file
          .openRead(4, 8)
          .expand((bytes) => bytes)
          .toList();
      expect(String.fromCharCodes(header), 'ftyp', reason: 'MP4 signature');
    },
  );
}
