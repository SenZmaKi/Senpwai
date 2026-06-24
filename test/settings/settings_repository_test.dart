import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/settings/settings.dart';

void main() {
  group('AppSettingsRepository', () {
    test('loads defaults when file is missing', () async {
      final dir = await Directory.systemTemp.createTemp('senpwai-settings-');
      addTearDown(() => dir.delete(recursive: true));
      final repo = AppSettingsRepository(
        file: File('${dir.path}/settings.json'),
      );

      final settings = await repo.load();

      expect(settings, isA<AppSettings>());
      expect(await repo.file.exists(), isTrue);
    });

    test('preserves corrupt file and rewrites defaults', () async {
      final dir = await Directory.systemTemp.createTemp('senpwai-settings-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/settings.json');
      await file.writeAsString('{ nope');
      final repo = AppSettingsRepository(file: file);

      final settings = await repo.load();

      expect(settings.content.showAdultContent, isFalse);
      expect(await File('${file.path}.corrupt').exists(), isTrue);
      expect(await file.exists(), isTrue);
    });
  });
}
