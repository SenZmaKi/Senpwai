import 'dart:io';
import 'package:external_path/external_path.dart';
import 'package:path/path.dart' as path;

Future<Directory> defaultDownloadsDirectory() async {
  if (Platform.isAndroid) {
    final downloadsPath = await ExternalPath.getExternalStoragePublicDirectory(
      ExternalPath.DIRECTORY_DOWNLOAD,
    );
    return Directory(downloadsPath);
  }

  final resolvedHome = _resolveHomeDirectoryPath();
  if (resolvedHome != null) {
    return Directory(path.join(resolvedHome, 'Downloads'));
  }

  if (Platform.isWindows) {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.isNotEmpty) {
      return Directory(path.join(userProfile, 'Downloads'));
    }
  }

  return Directory.current;
}

Future<Directory> defaultAnimeDownloadsRootDirectory() async {
  final base = await defaultDownloadsDirectory();
  return Directory(path.join(base.path, 'Anime'));
}

String? _resolveHomeDirectoryPath() {
  if (Platform.isWindows) {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.isNotEmpty) return userProfile;
    return null;
  }

  final home = Platform.environment['HOME'];
  if (Platform.isMacOS &&
      home != null &&
      home.contains('/Library/Containers/')) {
    final userName =
        Platform.environment['USER'] ?? Platform.environment['LOGNAME'];
    if (userName != null && userName.isNotEmpty) {
      return path.join('/Users', userName);
    }
  }

  if (home != null && home.isNotEmpty) return home;

  return null;
}
