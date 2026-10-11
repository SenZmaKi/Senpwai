import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/sources/animepahe.dart';
import 'package:senpwai/sources/shared/shared.dart' show SourceException;

import '../support/support.dart';

void main() {
  late Source source;

  setUpAll(() async {
    await setupTestApp();
    source = Source.getInstance();
  });

  List<EpisodeSession> select({
    required int firstEpisode,
    required int start,
    required int end,
    required List<int> hosted,
  }) => source.findEpisodeSessionsWithinRange(
    animeSession: 'anime-session',
    firstEpisode: firstEpisode,
    startEpisode: start,
    endEpisode: end,
    episodeSessions: [
      for (final number in hosted)
        EpisodeSession(session: 'session-$number', number: number),
    ],
  );

  test(
    'sequel episodes survive the planner filter with their original sessions',
    () {
      final requested = List.generate(12, (index) => index + 1);
      final selected = select(
        firstEpisode: 14,
        start: 1,
        end: 12,
        hosted: List.generate(12, (index) => index + 14),
      ).where((episode) => requested.contains(episode.number)).toList();

      expect(selected.map((episode) => episode.number), requested);
      expect(
        selected.map((episode) => episode.session),
        List.generate(12, (index) => 'session-${index + 14}'),
      );
      expect(
        Constants.buildEpisodePageUrl('anime-session', selected.first.session),
        endsWith('/play/anime-session/session-14'),
      );
    },
  );

  test(
    'overlapping source and season numbers select the correct sparse subset',
    () {
      final selected = select(
        firstEpisode: 14,
        start: 10,
        end: 16,
        hosted: List.generate(20, (index) => index + 14),
      ).where((episode) => [10, 14, 16].contains(episode.number)).toList();

      expect(selected.map((episode) => episode.number), [10, 14, 16]);
      expect(selected.map((episode) => episode.session), [
        'session-23',
        'session-27',
        'session-29',
      ]);
    },
  );

  test('later pages use the first episode of the anime as the offset', () {
    final selected = select(
      firstEpisode: 14,
      start: 31,
      end: 33,
      hosted: [44, 45, 46],
    );
    expect(selected.map((episode) => episode.number), [31, 32, 33]);
    expect(selected.map((episode) => episode.session), [
      'session-44',
      'session-45',
      'session-46',
    ]);
  });

  test(
    'ordinary numbering is unchanged and input sessions are not mutated',
    () {
      final episodes = [
        EpisodeSession(session: 'one', number: 1),
        EpisodeSession(session: 'two', number: 2),
        EpisodeSession(session: 'three', number: 3),
      ];
      final selected = source.findEpisodeSessionsWithinRange(
        animeSession: 'anime-session',
        firstEpisode: 1,
        startEpisode: 2,
        endEpisode: 3,
        episodeSessions: episodes,
      );
      expect(selected.map((episode) => episode.number), [2, 3]);
      expect(selected.map((episode) => episode.session), ['two', 'three']);
      expect(episodes.map((episode) => episode.number), [1, 2, 3]);
    },
  );

  test('missing range boundaries still raise a source error', () {
    expect(
      () => select(firstEpisode: 14, start: 1, end: 3, hosted: [14, 15]),
      throwsA(isA<SourceException>()),
    );
  });
}
