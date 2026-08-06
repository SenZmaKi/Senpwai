import 'dart:io';

import 'package:open_file/open_file.dart';
import 'package:open_file_manager/open_file_manager.dart';

/// Opens downloaded content with the operating system's default apps.
class PlatformFileOpener {
  const PlatformFileOpener._();

  /// Returns null on success, otherwise a user-facing error description.
  static Future<String?> openFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return 'The downloaded file could not be found.';
    }

    try {
      final result = await OpenFile.open(file.path);
      if (result.type == ResultType.done) {
        return null;
      }
      return result.message.isEmpty
          ? 'No app is available to open this file.'
          : result.message;
    } on Object catch (error) {
      return 'The file could not be opened: $error';
    }
  }

  /// Returns null on success, otherwise a user-facing error description.
  static Future<String?> openFolder(String folderPath) async {
    final directory = Directory(folderPath);
    if (!await directory.exists()) {
      return 'The download folder does not exist yet.';
    }

    try {
      if (Platform.isAndroid) {
        final opened = await openFileManager(
          androidConfig: AndroidConfig(
            folderType: AndroidFolderType.other,
            folderPath: directory.path,
          ),
        );
        return opened
            ? null
            : 'The system file manager could not open this folder.';
      }

      final command = switch (Platform.operatingSystem) {
        'windows' => ('explorer.exe', [directory.path]),
        'macos' => ('open', [directory.path]),
        'linux' => ('xdg-open', [directory.path]),
        _ => null,
      };
      if (command == null) {
        return 'Opening folders is not supported on this device.';
      }
      await Process.start(
        command.$1,
        command.$2,
        mode: ProcessStartMode.detached,
      );
      return null;
    } on Object catch (error) {
      return 'The download folder could not be opened: $error';
    }
  }
}
