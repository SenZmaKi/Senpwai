import 'dart:io';

class Constants {
  static const byte = 1024;
  static const megaByte = 1024 * 1024;
}

class UnsupportedPlatformException implements Exception {
  const UnsupportedPlatformException();

  @override
  String toString() => 'Unsupported platform: ${Platform.operatingSystem}';
}
