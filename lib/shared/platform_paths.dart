import 'dart:io';
import 'package:path/path.dart' as path;

Directory defaultDownloadsDirectory() {
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

Directory defaultAnimeDownloadsRootDirectory() {
  return Directory(path.join(defaultDownloadsDirectory().path, 'Anime'));
}

String? _resolveHomeDirectoryPath() {
  if (Platform.isWindows) {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.isNotEmpty) {
      return userProfile;
    }
    return null;
  }

  final home = Platform.environment['HOME'];
  if (Platform.isMacOS &&
      home != null &&
      home.contains('/Library/Containers/')) {
    final userName = Platform.environment['USER'] ?? Platform.environment['LOGNAME'];
    if (userName != null && userName.isNotEmpty) {
      return path.join('/Users', userName);
    }
  }

  if (home != null && home.isNotEmpty) {
    return home;
  }

  return null;
}
