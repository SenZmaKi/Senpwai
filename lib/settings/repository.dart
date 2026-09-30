import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/settings/defaults.dart';
import 'package:senpwai/settings/models.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/platform_paths.dart';

final _log = Logger('senpwai.settings.repository');

class AppSettingsRepository {
  final File file;
  Future<void> _saveTail = Future.value();
  int _temporaryFileSequence = 0;

  AppSettingsRepository({required this.file});

  Future<AppSettings> load() async {
    if (!await file.exists()) {
      final defaults = await createDefaults();
      await save(defaults);
      return defaults;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Settings root must be a JSON object.');
      }
      final parsedSettings = AppSettings.fromJson(decoded);
      final settings = await _withDefaultDownloadRoot(parsedSettings);
      if (parsedSettings.downloads.effectiveRootDirectories.isEmpty &&
          settings.downloads.effectiveRootDirectories.isNotEmpty) {
        await save(settings);
      }
      return settings;
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
      final defaults = await createDefaults();
      await save(defaults);
      return defaults;
    }
  }

  /// Serializes writes so rapid settings changes cannot race over the same
  /// destination or temporary file.
  Future<void> save(AppSettings settings) {
    final operation = _saveTail
        .catchError((Object _) {})
        .then((_) => _writeAtomically(settings));
    // A failed write must not prevent a later settings change from persisting.
    _saveTail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _writeAtomically(AppSettings settings) async {
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.${_temporaryFileSequence++}.tmp');
    const encoder = JsonEncoder.withIndent('  ');
    await tempFile.writeAsString('${encoder.convert(settings.toJson())}\n');
    // On macOS, rename replaces an existing file atomically.  Do not delete
    // the destination first: that creates a missing-file window for readers.
    await tempFile.rename(file.path);
  }

  /// Creates the same device-aware baseline used on a first launch.
  Future<AppSettings> createDefaults() => AppSettingsDefaultResolver.resolve();

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

  Future<AppSettings> _withDefaultDownloadRoot(AppSettings settings) async {
    if (settings.downloads.effectiveRootDirectories.isNotEmpty) {
      return settings;
    }
    final defaultRoot = await defaultAnimeDownloadsRootDirectory();
    return settings.copyWith(
      downloads: settings.downloads.copyWith(
        defaultRootDirectory: defaultRoot.path,
        rootDirectories: [defaultRoot.path],
      ),
    );
  }
}
