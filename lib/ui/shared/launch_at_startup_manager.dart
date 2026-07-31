import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

class LaunchAtStartupManager {
  static LaunchAtStartupManager? _instance;

  bool _configured = false;

  static LaunchAtStartupManager getInstance() {
    _instance ??= LaunchAtStartupManager();
    return _instance!;
  }

  Future<void> init(bool enabled) async {
    if (!supportsLaunchAtStartup) return;
    _configure();
    await setEnabled(enabled);
  }

  Future<void> setEnabled(bool enabled) async {
    if (!supportsLaunchAtStartup) return;
    _configure();
    if (enabled) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }

  void _configure() {
    if (_configured) return;
    launchAtStartup.setup(
      appName: 'Senpwai',
      appPath: Platform.resolvedExecutable,
      packageName: 'com.example.senpwai',
    );
    _configured = true;
  }
}

bool get supportsLaunchAtStartup =>
    !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);
