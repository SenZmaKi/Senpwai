import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/shared/persistence/window_state_repository.dart';

void main() {
  late Directory directory;
  late File file;
  late WindowStateRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('senpwai-window-state-');
    file = File('${directory.path}/window_state.json');
    repository = WindowStateRepository(file: file);
  });

  tearDown(() => directory.delete(recursive: true));

  test('round trips finite positive window bounds', () async {
    const bounds = WindowBounds(x: -20, y: 15, width: 1280, height: 720);

    await repository.save(bounds);
    final loaded = await repository.load();

    expect(loaded?.x, -20);
    expect(loaded?.y, 15);
    expect(loaded?.width, 1280);
    expect(loaded?.height, 720);
  });

  test(
    'rejects invalid dimensions without treating valid JSON as corrupt',
    () async {
      await file.writeAsString('{"x":0,"y":0,"width":0,"height":720}');

      expect(await repository.load(), isNull);
      expect(await file.exists(), isTrue);
      expect(await File('${file.path}.corrupt').exists(), isFalse);
    },
  );

  test('preserves malformed JSON for diagnostics', () async {
    await file.writeAsString('{broken');

    expect(await repository.load(), isNull);
    expect(await file.exists(), isFalse);
    expect(await File('${file.path}.corrupt').readAsString(), '{broken');
  });

  test('replaces an older corrupt backup', () async {
    await file.writeAsString('new-corruption');
    await File('${file.path}.corrupt').writeAsString('old-corruption');

    expect(await repository.load(), isNull);
    expect(await File('${file.path}.corrupt').readAsString(), 'new-corruption');
  });
}
