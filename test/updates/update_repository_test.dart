import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/shared/persistence/app_paths.dart';
import 'package:senpwai/updates/models.dart';
import 'package:senpwai/updates/update_repository.dart';

void main() {
  late Directory directory;
  late AppPaths paths;
  late UpdateRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('senpwai-update-repo-');
    paths = await AppPaths.fromRootDirectory(directory);
    repository = UpdateRepository(paths: paths);
  });

  tearDown(() => directory.delete(recursive: true));

  test('round trips a prepared update whose artifact exists', () async {
    final prepared = _prepared(repository);
    await File(prepared.filePath).writeAsBytes([1, 2, 3]);

    await repository.savePrepared(prepared);
    final loaded = await repository.loadPrepared();

    expect(loaded?.version, '3.1.0');
    expect(loaded?.build, 7);
    expect(loaded?.artifact.fileName, 'update.zip');
    expect(loaded?.filePath, prepared.filePath);
  });

  test('clears stale state when the downloaded artifact is missing', () async {
    await repository.savePrepared(_prepared(repository));

    expect(await repository.loadPrepared(), isNull);
    expect(await paths.updateStateFile.exists(), isFalse);
  });

  test(
    'keeps platform-prepared state after its source artifact moves',
    () async {
      final prepared = _prepared(repository).copyWith(platformPrepared: true);
      await repository.savePrepared(prepared);

      final loaded = await repository.loadPrepared();

      expect(loaded?.platformPrepared, isTrue);
    },
  );

  test('clears malformed prepared state', () async {
    await paths.updateStateFile.writeAsString('{broken');

    expect(await repository.loadPrepared(), isNull);
    expect(await paths.updateStateFile.exists(), isFalse);
  });
}

PreparedUpdate _prepared(UpdateRepository repository) {
  final artifact = UpdateArtifact(
    platform: UpdateTarget.current.platform,
    architecture: UpdateTarget.current.architecture,
    url: Uri.parse('https://github.com/acme/releases/update.zip'),
    fileName: 'update.zip',
    sizeBytes: 3,
    sha256: 'a' * 64,
  );
  return PreparedUpdate(
    version: '3.1.0',
    build: 7,
    artifact: artifact,
    filePath: repository.artifactFile(artifact).path,
    platformPrepared: false,
  );
}
