import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/tracking/models.dart';

final _log = Logger('senpwai.tracking.repository');

class TrackingRepository {
  final File file;

  const TrackingRepository({required this.file});

  Future<List<TrackedAnime>> load() async {
    if (!await file.exists()) {
      await save(const []);
      return const [];
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      final items = decoded is Map<String, dynamic>
          ? decoded['trackedAnime']
          : decoded;
      if (items is! List) {
        throw const FormatException('Tracked anime root must be a list.');
      }
      return items
          .whereType<Map<String, dynamic>>()
          .map(TrackedAnime.fromJson)
          .where((tracked) => tracked.downloadFolder.trim().isNotEmpty)
          .toList();
    } on Object catch (error, stackTrace) {
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

  Future<void> save(List<TrackedAnime> trackedAnime) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    const encoder = JsonEncoder.withIndent('  ');
    await tempFile.writeAsString(
      '${encoder.convert({'trackedAnime': trackedAnime.map((tracked) => tracked.toJson()).toList()})}\n',
    );
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }

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
