import 'dart:convert';
import 'dart:io';

import 'package:senpwai/shared/persistence/app_paths.dart';
import 'package:senpwai/updates/models.dart';

class PreparedUpdate {
  final String version;
  final int build;
  final UpdateArtifact artifact;
  final String filePath;
  final bool platformPrepared;

  const PreparedUpdate({
    required this.version,
    required this.build,
    required this.artifact,
    required this.filePath,
    required this.platformPrepared,
  });

  factory PreparedUpdate.fromJson(Map<String, dynamic> json) => PreparedUpdate(
    version: json['version'] as String,
    build: json['build'] as int,
    artifact: UpdateArtifact.fromJson(json['artifact'] as Map<String, dynamic>),
    filePath: json['filePath'] as String,
    platformPrepared: json['platformPrepared'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'build': build,
    'artifact': artifact.toJson(),
    'filePath': filePath,
    'platformPrepared': platformPrepared,
  };

  PreparedUpdate copyWith({bool? platformPrepared}) => PreparedUpdate(
    version: version,
    build: build,
    artifact: artifact,
    filePath: filePath,
    platformPrepared: platformPrepared ?? this.platformPrepared,
  );
}

class UpdateRepository {
  final AppPaths paths;

  const UpdateRepository({required this.paths});

  File artifactFile(UpdateArtifact artifact) => File(
    '${paths.updatesDirectory.path}${Platform.pathSeparator}${artifact.fileName}',
  );

  File partialArtifactFile(UpdateArtifact artifact) =>
      File('${artifactFile(artifact).path}.part');

  Future<PreparedUpdate?> loadPrepared() async {
    if (!await paths.updateStateFile.exists()) return null;
    try {
      final json = jsonDecode(await paths.updateStateFile.readAsString());
      if (json is! Map<String, dynamic>) return null;
      final prepared = PreparedUpdate.fromJson(json);
      if (!await File(prepared.filePath).exists() &&
          !prepared.platformPrepared) {
        await clearPrepared();
        return null;
      }
      return prepared;
    } catch (_) {
      await clearPrepared();
      return null;
    }
  }

  Future<void> savePrepared(PreparedUpdate prepared) => paths.updateStateFile
      .writeAsString('${jsonEncode(prepared.toJson())}\n', flush: true);

  Future<void> clearPrepared() async {
    if (await paths.updateStateFile.exists()) {
      await paths.updateStateFile.delete();
    }
  }
}
