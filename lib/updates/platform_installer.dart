import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:senpwai/updates/models.dart';

enum UpdateInstallDisposition {
  externalInstallerOpened,
  applicationWillRestart,
  quitThenRelaunch,
}

abstract class UpdatePlatformInstaller {
  const UpdatePlatformInstaller();

  bool get preparesForNextLaunch;

  Future<bool> prepare(File artifact, AppRelease release);

  Future<UpdateInstallDisposition> installAndRestart(
    File artifact,
    AppRelease release,
  );

  static UpdatePlatformInstaller current() {
    if (Platform.isAndroid) return const AndroidUpdateInstaller();
    if (Platform.isWindows) return const WindowsUpdateInstaller();
    if (Platform.isLinux) return const LinuxUpdateInstaller();
    return const UnsupportedUpdateInstaller();
  }
}

class AndroidUpdateInstaller extends UpdatePlatformInstaller {
  static const _channel = MethodChannel('senpwai/update_installer');

  const AndroidUpdateInstaller();

  @override
  bool get preparesForNextLaunch => false;

  @override
  Future<bool> prepare(File artifact, AppRelease release) async => false;

  @override
  Future<UpdateInstallDisposition> installAndRestart(
    File artifact,
    AppRelease release,
  ) async {
    await _channel.invokeMethod<void>('installApk', {'path': artifact.path});
    return UpdateInstallDisposition.externalInstallerOpened;
  }
}

class WindowsUpdateInstaller extends UpdatePlatformInstaller {
  static const _channel = MethodChannel('senpwai/update_installer');

  const WindowsUpdateInstaller();

  @override
  bool get preparesForNextLaunch => true;

  @override
  Future<bool> prepare(File artifact, AppRelease release) async {
    final result = await Process.run('powershell.exe', [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      _encodedPowerShell(
        "Add-AppxPackage -Path '${_escapePowerShell(artifact.path)}' "
        '-DeferRegistrationWhenPackagesAreInUse -ErrorAction Stop',
      ),
    ]);
    if (result.exitCode != 0) {
      throw ProcessException(
        'powershell.exe',
        const [],
        result.stderr.toString().trim(),
        result.exitCode,
      );
    }
    return true;
  }

  @override
  Future<UpdateInstallDisposition> installAndRestart(
    File artifact,
    AppRelease release,
  ) async {
    await _channel.invokeMethod<void>('registerApplicationRestart');
    await Process.start('powershell.exe', [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      _encodedPowerShell(
        "Add-AppxPackage -Path '${_escapePowerShell(artifact.path)}' "
        '-ForceApplicationShutdown -ErrorAction Stop',
      ),
    ], mode: ProcessStartMode.detached);
    return UpdateInstallDisposition.applicationWillRestart;
  }

  static String _escapePowerShell(String value) => value.replaceAll("'", "''");

  static String _encodedPowerShell(String script) {
    final units = script.codeUnits;
    final bytes = Uint8List(units.length * 2);
    final data = ByteData.sublistView(bytes);
    for (var index = 0; index < units.length; index++) {
      data.setUint16(index * 2, units[index], Endian.little);
    }
    return base64.encode(bytes);
  }
}

class LinuxUpdateInstaller extends UpdatePlatformInstaller {
  const LinuxUpdateInstaller();

  @override
  bool get preparesForNextLaunch => true;

  String get _appImagePath {
    final value = Platform.environment['APPIMAGE'];
    if (value == null || value.trim().isEmpty) {
      throw const FileSystemException(
        'Automatic Linux updates require the AppImage release.',
      );
    }
    return path.canonicalize(value);
  }

  @override
  Future<bool> prepare(File artifact, AppRelease release) async {
    final appImage = File(_appImagePath);
    final parent = appImage.parent;
    final replacement = File('${appImage.path}.update');
    final backup = File('${appImage.path}.previous');
    await parent.create(recursive: true);
    if (await replacement.exists()) await replacement.delete();
    await artifact.copy(replacement.path);
    await Process.run('chmod', ['755', replacement.path]);
    if (await backup.exists()) await backup.delete();
    await appImage.copy(backup.path);
    await replacement.rename(appImage.path);
    return true;
  }

  @override
  Future<UpdateInstallDisposition> installAndRestart(
    File artifact,
    AppRelease release,
  ) async {
    final appImagePath = _appImagePath;
    final processId = pid.toString();
    await Process.start('/bin/sh', [
      '-c',
      r'while kill -0 "$1" 2>/dev/null; do sleep 0.1; done; exec "$2"',
      'senpwai-update-restart',
      processId,
      appImagePath,
    ], mode: ProcessStartMode.detached);
    return UpdateInstallDisposition.quitThenRelaunch;
  }
}

class UnsupportedUpdateInstaller extends UpdatePlatformInstaller {
  const UnsupportedUpdateInstaller();

  @override
  bool get preparesForNextLaunch => false;

  @override
  Future<bool> prepare(File artifact, AppRelease release) {
    throw UnsupportedError(
      'Automatic updates are unavailable on this platform.',
    );
  }

  @override
  Future<UpdateInstallDisposition> installAndRestart(
    File artifact,
    AppRelease release,
  ) {
    throw UnsupportedError(
      'Automatic updates are unavailable on this platform.',
    );
  }
}
