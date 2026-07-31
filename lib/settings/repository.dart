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

  const AppSettingsRepository({required this.file});

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
