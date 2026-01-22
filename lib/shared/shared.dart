import 'dart:io';

class Constants {
  static const kiloByte = 1024;
  static const megaByte = kiloByte * kiloByte;
  static const gigaByte = megaByte * kiloByte;
  static const teraByte = gigaByte * kiloByte;
}

class UnsupportedPlatformException implements Exception {
  const UnsupportedPlatformException();

  @override
  String toString() => 'Unsupported platform: ${Platform.operatingSystem}';
}
