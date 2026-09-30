import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:senpwai/sources/animepahe.dart' as animepahe;
import 'package:senpwai/sources/nyaa.dart' as nyaa;
import 'package:senpwai/sources/shared/shared.dart';
import 'package:senpwai/sources/tokyoinsider.dart' as tokyoinsider;

void main() {
  group('shared source parsing', () {
    test('parses canonical and dimensions-style resolutions', () {
      expect(parseResolution('[Group] Show 1080p'), Resolution.res1080p);
      expect(parseResolution('Show 1920x1080 HEVC'), Resolution.res1080p);
      expect(parseResolution('Show 2160p'), Resolution.res2160p);
      expect(parseResolution('Show 900p'), isNull);
      expect(parseResolution('Show 1080 pixels'), isNull);
    });

    test('resolution factories reject unknown and malformed values', () {
      expect(Resolution.fromInt(720), Resolution.res720p);
      expect(Resolution.fromInt(900), isNull);
      expect(Resolution.fromString('480'), Resolution.res480p);
      expect(Resolution.fromString('480p'), isNull);
    });

    test('language and resolution labels are user-facing', () {
      expect(Language.japanese.toString(), 'Japanese');
      expect(Language.english.toString(), 'English');
      expect(Resolution.res1440p.toString(), '1440p');
    });
  });

  group('AnimePahe models', () {
    test('AnimeResult accepts integer and missing scores from API JSON', () {
      final integerScore = animepahe.AnimeResult.fromJson({
        'id': 1,
        'title': 'Frieren',
        'type': 'TV',
        'episodes': 28,
        'status': 'Finished Airing',
        'season': 'fall',
        'year': 2023,
        'score': 9,
        'poster': 'poster.jpg',
        'session': 'abc',
      });
      final missingScore = animepahe.AnimeResult.fromJson({
        'id': 2,
        'title': 'Unknown',
        'type': 'ONA',
        'episodes': 1,
        'status': 'Finished Airing',
        'season': 'winter',
        'year': 2026,
        'poster': 'poster.jpg',
        'session': 'def',
      });

      expect(integerScore.score, 9.0);
      expect(missingScore.score, 0.0);
    });

    test('episode page URL preserves both opaque sessions', () {
      expect(
        animepahe.Constants.buildEpisodePageUrl('anime-session', 'ep-session'),
        endsWith('/play/anime-session/ep-session'),
      );
    });
  });

  group('Nyaa fixture parser', () {
    test('parses source fields and binary size units', () {
      final results = nyaa.parseSearchResultsHtml('''
        <table><tbody>
          ${_nyaaRow(size: '1.5 GiB', timestamp: 1700000000)}
          ${_nyaaRow(size: '512 MiB', timestamp: 1700000100, id: 2)}
          ${_nyaaRow(size: '2 KiB', timestamp: 1700000200, id: 3)}
        </tbody></table>
      ''');

      expect(results, hasLength(3));
      expect(results[0].filename, '[Group] Frieren - 01 [1080p]');
      expect(results[0].torrentFileUrl, 'https://nyaa.si/download/1.torrent');
      expect(results[0].magnetUrl, startsWith('magnet:?xt='));
      expect(results[0].sizeBytes, 1610612736);
      expect(results[1].sizeBytes, 512 * 1024 * 1024);
      expect(results[2].sizeBytes, 2 * 1024);
      expect(results[0].seeders, 20);
      expect(results[0].leechers, 3);
      expect(results[0].torrentFileDownloadCount, 99);
      expect(results[0].dateAdded.millisecondsSinceEpoch, 1700000000000);
    });

    test('ignores categories other than English-translated anime', () {
      final results = nyaa.parseSearchResultsHtml('''
        <table><tbody>
          ${_nyaaRow(category: 'Anime - Non-English-translated')}
          ${_nyaaRow(category: 'Literature - English-translated', id: 2)}
        </tbody></table>
      ''');

      expect(results, isEmpty);
    });

    test('skips malformed rows while preserving valid neighbors', () {
      final results = nyaa.parseSearchResultsHtml('''
        <table><tbody>
          <tr><td><a title="Anime - English-translated"></a></td></tr>
          ${_nyaaRow()}
          <tr>
            <td><a title="Anime - English-translated"></a></td>
            <td><a>Missing downloads</a></td>
            <td></td><td>1 GiB</td><td data-timestamp="1"></td>
            <td>1</td><td>0</td><td>1</td>
          </tr>
        </tbody></table>
      ''');

      expect(results, hasLength(1));
      expect(results.single.seeders, 20);
    });

    test('throws a source exception for unsupported size units', () {
      expect(
        () => nyaa.parseSearchResultsHtml(
          '<table><tbody>${_nyaaRow(size: '1.5 GB')}</tbody></table>',
        ),
        throwsA(isA<SourceException>()),
      );
    });
  });

  group('TokyoInsider fixture selectors', () {
    test('extracts result links from both alternating row styles', () {
      final document = html.parse('''
        <div class="c_h2"><div><a href="/anime/a">Show A</a></div></div>
        <div class="c_h2b"><div><a href="/anime/b">Show B</a></div></div>
        <div class="other"><div><a href="/anime/c">Ignore</a></div></div>
      ''');

      final results = tokyoinsider.parsePageResults(document);

      expect(results.map((element) => element.text.trim()), [
        'Show A',
        'Show B',
      ]);
    });
  });
}

String _nyaaRow({
  String size = '1.5 GiB',
  int timestamp = 1700000000,
  int id = 1,
  String category = 'Anime - English-translated',
}) =>
    '''
  <tr>
    <td><a title="$category"></a></td>
    <td><a href="/view/$id">[Group] Frieren - 01 [1080p]</a></td>
    <td>
      <a href="/download/$id.torrent">torrent</a>
      <a href="magnet:?xt=urn:btih:$id">magnet</a>
    </td>
    <td>$size</td>
    <td data-timestamp="$timestamp"></td>
    <td>20</td><td>3</td><td>99</td>
  </tr>
''';
