import 'dart:io';
import 'package:path/path.dart' as path;

Directory defaultDownloadsDirectory() {
  if (Platform.isWindows) {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.isNotEmpty) {
      return Directory(path.join(userProfile, 'Downloads'));
    }
  }

  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return Directory(path.join(home, 'Downloads'));
  }

  return Directory.current;
}
