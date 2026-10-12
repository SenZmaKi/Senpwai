import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/ui/pages/settings_page/tracked_folder_control.dart';

void main() {
  testWidgets(
    'folder selection saves chosen directory; cancellation preserves it',
    (tester) async {
      final picker = _Picker();
      FilePicker.platform = picker;
      final folder = Directory.systemTemp.createTempSync('tracked-folder-');
      addTearDown(() => folder.deleteSync(recursive: true));
      final saved = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackedFolderControl(
              folder: folder.path,
              onChanged: (value) async => saved.add(value),
            ),
          ),
        ),
      );
      picker.result = '/new/folder';
      await tester.tap(find.byType(TextButton));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(saved, ['/new/folder']);
      expect(picker.initialDirectory, folder.path);
      picker.result = null;
      await tester.tap(find.byType(TextButton));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(saved, ['/new/folder']);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Picker extends FilePicker {
  String? result;
  String? initialDirectory;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async {
    this.initialDirectory = initialDirectory;
    return result;
  }
}
