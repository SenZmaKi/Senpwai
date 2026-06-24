import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/settings/models.dart';
import 'package:senpwai/shared/log.dart';

final _log = Logger('senpwai.settings.repository');

class AppSettingsRepository {
  final File file;

  const AppSettingsRepository({required this.file});

  Future<AppSettings> load() async {
    if (!await file.exists()) {
      final defaults = AppSettings.defaults();
      await save(defaults);
      return defaults;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Settings root must be a JSON object.');
      }
      return AppSettings.fromJson(decoded);
    } on Object catch (error, stackTrace) {
      _log.warningWithMetadata(
        'Failed to load settings; preserving corrupt settings and resetting',
        metadata: {
          'path': file.path,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      await _preserveCorruptFile();
      final defaults = AppSettings.defaults();
      await save(defaults);
      return defaults;
    }
  }

  Future<void> save(AppSettings settings) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    const encoder = JsonEncoder.withIndent('  ');
    await tempFile.writeAsString('${encoder.convert(settings.toJson())}\n');
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
