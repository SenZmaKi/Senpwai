import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/torrent_identity.dart';

void main() {
  PreparedTorrentDownloadJob torrent(List<int> bytes) =>
      PreparedTorrentDownloadJob(
        source: AnimeSource.nyaa,
        animeTitle: 'Show',
        displayTitle: 'Show',
        destinationDirectory: '/tmp/show',
        totalBytes: 100,
        torrentData: Uint8List.fromList(bytes),
        torrentName: 'show.torrent',
        selectedFileIndices: [0],
        selectedFilePaths: ['/tmp/show/episode.mkv'],
        renamedFilePaths: const {},
      );

  test('new batch detects an active torrent with equal metadata', () {
    final jobs = <String, PreparedDownloadJob>{
      'existing': torrent([1, 2, 3]),
    };
    expect(
      activeTorrentOwner(jobs, ['existing'], Uint8List.fromList([1, 2, 3])),
      'existing',
    );
    expect(
      activeTorrentOwner(jobs, ['existing'], Uint8List.fromList([1, 2, 4])),
      isNull,
    );
  });

  test('resume excludes its own handle but detects another active owner', () {
    final jobs = <String, PreparedDownloadJob>{
      'resuming': torrent([1, 2, 3]),
      'other': torrent([1, 2, 3]),
    };
    expect(
      activeTorrentOwner(
        jobs,
        ['resuming'],
        Uint8List.fromList([1, 2, 3]),
        exceptId: 'resuming',
      ),
      isNull,
    );
    expect(
      activeTorrentOwner(
        jobs,
        ['resuming', 'other'],
        Uint8List.fromList([1, 2, 3]),
        exceptId: 'resuming',
      ),
      'other',
    );
  });
}
