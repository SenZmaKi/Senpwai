import 'dart:io';

import 'package:window_manager/window_manager.dart';

class WindowManager {
  static WindowManager? _instance;

  static WindowManager getInstance() {
    _instance ??= WindowManager();
    return _instance!;
  }

  Future<void> init() async {
    if (Platform.isAndroid || Platform.isIOS) return;
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions();
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await focus();
    });
  }

  Future<void> focus() async {
    if (Platform.isAndroid || Platform.isIOS) return;
    await windowManager.show();
    await windowManager.focus();
  }
}
