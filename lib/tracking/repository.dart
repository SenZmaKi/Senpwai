import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/persistence/json_file_store.dart';
import 'package:senpwai/tracking/models.dart';

final _log = Logger('senpwai.tracking.repository');

class TrackingRepository {
  final File file;

  final JsonFileStore _store;

  TrackingRepository({required this.file}) : _store = JsonFileStore(file);

  Future<List<TrackedAnime>> load() async {
    try {
      final decoded = await _store.read();
      if (decoded == null) {
        await save(const []);
        return const [];
      }
      final items = decoded['trackedAnime'];
      if (items is! List) {
        throw const FormatException('Tracked anime root must be a list.');
      }
      return items
          .whereType<Map<String, dynamic>>()
          .map(TrackedAnime.fromJson)
          .where((tracked) => tracked.downloadFolder.trim().isNotEmpty)
          .toList();
    } on FormatException catch (error, stackTrace) {
      _log.warningWithMetadata(
        'Failed to load tracked anime; preserving corrupt file and resetting',
        metadata: {
          'path': file.path,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      await _preserveCorruptFile();
      await save(const []);
      return const [];
    }
  }

  Future<void> save(List<TrackedAnime> trackedAnime) => _store.write({
    'trackedAnime': trackedAnime.map((tracked) => tracked.toJson()).toList(),
  });

  Future<void> _preserveCorruptFile() async {
    if (!await file.exists()) return;
    final corruptPath = path.join(
      file.parent.path,
      '${path.basename(file.path)}.corrupt',
    );
    final corruptFile = File(corruptPath);
    if (await corruptFile.exists()) {
      await corruptFile.delete();
    }
    await file.rename(corruptPath);
  }
}
