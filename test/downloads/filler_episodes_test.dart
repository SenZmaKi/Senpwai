import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/anilist/models.dart';
import 'package:senpwai/downloads/filler_episodes.dart';

void main() {
  group('AnimeFillerService', () {
    test('matches normalized titles and parses only filler rows', () async {
      final server = _FixtureServer({
        '/shows': _showIndex([
          ('My Hero Academia (TV)', '/shows/my-hero-academia'),
        ]),
        '/shows/my-hero-academia': _fillerPage(
          'My Hero Academia (TV) Filler List',
          fillerEpisodes: [4, 8],
          canonEpisodes: [1, 2, 3],
        ),
      });

      final result = await AnimeFillerService(
        dio: server.dio,
      ).getFillerEpisodes(anime: _anime('My Hero Academia'), episodeCount: 12);

      expect(result, {4, 8});
      expect(server.requests, ['/shows', '/shows/my-hero-academia']);
    });

    test('prefers a strict title match over a parenthetical alias', () async {
      final server = _FixtureServer({
        '/shows': _showIndex([
          ('Naruto (Anime)', '/shows/wrong'),
          ('Naruto', '/shows/right'),
        ]),
        '/shows/right': _fillerPage('Naruto Filler List', fillerEpisodes: [26]),
      });

      final result = await AnimeFillerService(
        dio: server.dio,
      ).getFillerEpisodes(anime: _anime('Naruto'), episodeCount: 220);

      expect(result, {26});
      expect(server.requests, ['/shows', '/shows/right']);
    });

    test('ignores a page whose title does not match its index entry', () async {
      final server = _FixtureServer({
        '/shows': _showIndex([('Bleach', '/shows/bleach')]),
        '/shows/bleach': _fillerPage(
          'One Piece Filler List',
          fillerEpisodes: [5],
        ),
      });

      final result = await AnimeFillerService(
        dio: server.dio,
      ).getFillerEpisodes(anime: _anime('Bleach'), episodeCount: 100);

      expect(result, isEmpty);
    });

    test(
      'rejects a filler list extending past the anime episode count',
      () async {
        final server = _FixtureServer({
          '/shows': _showIndex([('Short Show', '/shows/short')]),
          '/shows/short': _fillerPage(
            'Short Show Filler List',
            fillerEpisodes: [3, 99],
          ),
        });

        final result = await AnimeFillerService(
          dio: server.dio,
        ).getFillerEpisodes(anime: _anime('Short Show'), episodeCount: 12);

        expect(result, isEmpty);
      },
    );

    test('skips network access for invalid episode counts', () async {
      final server = _FixtureServer(const {});

      final result = await AnimeFillerService(
        dio: server.dio,
      ).getFillerEpisodes(anime: _anime('Anything'), episodeCount: 0);

      expect(result, isEmpty);
      expect(server.requests, isEmpty);
    });

    test(
      'skips sequel titles because numbering differs from the site',
      () async {
        final server = _FixtureServer(const {});

        final result = await AnimeFillerService(dio: server.dio)
            .getFillerEpisodes(
              anime: _anime('My Hero Academia 2nd Season'),
              episodeCount: 25,
            );

        expect(result, isEmpty);
        expect(server.requests, isEmpty);
      },
    );

    test('coalesces concurrent show-index requests', () async {
      final server = _FixtureServer({
        '/shows': _showIndex([('Naruto', '/shows/naruto')]),
        '/shows/naruto': _fillerPage(
          'Naruto Filler List',
          fillerEpisodes: [26],
        ),
      });
      final service = AnimeFillerService(dio: server.dio);

      final results = await Future.wait([
        service.getFillerEpisodes(anime: _anime('Naruto'), episodeCount: 220),
        service.getFillerEpisodes(anime: _anime('Naruto'), episodeCount: 220),
      ]);

      expect(results, everyElement({26}));
      expect(server.requests.where((path) => path == '/shows'), hasLength(1));
    });

    test('fails open when source markup is malformed', () async {
      final server = _FixtureServer({'/shows': '<html>no show list</html>'});

      final result = await AnimeFillerService(
        dio: server.dio,
      ).getFillerEpisodes(anime: _anime('Naruto'), episodeCount: 220);

      expect(result, isEmpty);
    });
  });
}

AnilistAnime _anime(String title) => AnilistAnime(
  id: 1,
  title: AnilistTitle(romaji: title),
  genres: const [],
);

String _showIndex(List<(String, String)> shows) =>
    '''
  <div id="ShowList"><ul>
    ${shows.map((show) => '<li><a href="${show.$2}">${show.$1}</a></li>').join()}
  </ul></div>
''';

String _fillerPage(
  String title, {
  required List<int> fillerEpisodes,
  List<int> canonEpisodes = const [],
}) =>
    '''
  <h1>$title</h1>
  <table class="EpisodeList"><tbody>
    ${fillerEpisodes.map((episode) => '<tr class="filler"><td class="Number">$episode</td></tr>').join()}
    ${canonEpisodes.map((episode) => '<tr class="canon"><td class="Number">$episode</td></tr>').join()}
  </tbody></table>
''';

class _FixtureServer {
  final Dio dio = Dio();
  final List<String> requests = [];

  _FixtureServer(Map<String, String> fixtures) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options.uri.path);
          final body = fixtures[options.uri.path];
          if (body == null) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<void>(
                  requestOptions: options,
                  statusCode: 404,
                ),
                type: DioExceptionType.badResponse,
              ),
            );
            return;
          }
          handler.resolve(
            Response<String>(
              requestOptions: options,
              statusCode: 200,
              data: body,
            ),
          );
        },
      ),
    );
  }
}
