import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/ui/shared/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart' show windowManager;

final _log = Logger('senpwai.ui.desktop_tray');

/// Owns the desktop tray lifecycle and keeps the window reachable after close.
class DesktopTrayController with TrayListener {
  DesktopTrayController._();

  static final instance = DesktopTrayController._();

  static const _showWindowKey = 'show_senpwai';
  static const _checkTrackedAnimeKey = 'check_tracked_anime';
  static const _quitKey = 'quit';

  Future<void> Function()? _checkTrackedAnime;
  bool _initialized = false;
  bool _quitting = false;

  Future<void> initialize({
    required Future<void> Function() onCheckTrackedAnime,
    required bool closeToTray,
  }) async {
    if (!supportsWindowCustomization) {
      _log.info('Tray initialization skipped: unsupported platform');
      return;
    }
    _checkTrackedAnime = onCheckTrackedAnime;
    if (_initialized) {
      _log.info('Tray initialization skipped: already initialized');
      return;
    }

    try {
      _log.infoWithMetadata('Initializing tray', metadata: {'icon': _iconPath});
      trayManager.addListener(this);
      await trayManager.setIcon(_iconPath);
      await trayManager.setToolTip('Senpwai');
      await _setContextMenu(isWindowVisible: await windowManager.isVisible());
      await setCloseToTray(closeToTray);
      _initialized = true;
      _log.infoWithMetadata(
        'Tray initialized',
        metadata: {'closeToTray': closeToTray},
      );
    } on Object catch (error, stackTrace) {
      trayManager.removeListener(this);
      _log.severeWithMetadata(
        'Tray initialization failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> setCloseToTray(bool enabled) {
    return WindowManager.getInstance().configureCloseToTray(
      enabled: enabled,
      onClose: _hideWindow,
    );
  }

  String get _iconPath {
    if (!Platform.isWindows) {
      return 'assets/images/senpwai-icon.png';
    }

    return [
      File(Platform.resolvedExecutable).parent.path,
      'data',
      'flutter_assets',
      'windows',
      'runner',
      'resources',
      'app_icon.ico',
    ].join(Platform.pathSeparator);
  }

  Future<void> _hideWindow() async {
    if (_quitting) {
      _log.info('Ignoring hide request: explicit quit is in progress');
      return;
    }
    try {
      _log.infoWithMetadata(
        'Hiding window to tray',
        metadata: {'visibleBefore': await windowManager.isVisible()},
      );
      await windowManager.hide();
      await _setContextMenu(isWindowVisible: false);
      _log.infoWithMetadata(
        'Window hidden to tray',
        metadata: {'visibleAfter': await windowManager.isVisible()},
      );
    } on Object catch (error, stackTrace) {
      _log.severeWithMetadata(
        'Failed to hide window to tray',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _toggleWindowVisibility() async {
    try {
      final visible = await windowManager.isVisible();
      _log.infoWithMetadata(
        'Toggling tray window visibility',
        metadata: {'visibleBefore': visible},
      );
      if (visible) {
        await _hideWindow();
      } else {
        await _showWindow();
      }
    } on Object catch (error, stackTrace) {
      _log.severeWithMetadata(
        'Tray visibility toggle failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _showWindow() async {
    try {
      _log.info('Showing and focusing window from tray');
      await WindowManager.getInstance().focus();
      await _setContextMenu(isWindowVisible: true);
      _log.infoWithMetadata(
        'Window shown from tray',
        metadata: {'visibleAfter': await windowManager.isVisible()},
      );
    } on Object catch (error, stackTrace) {
      _log.severeWithMetadata(
        'Failed to show window from tray',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _showContextMenu() async {
    try {
      await _setContextMenu(isWindowVisible: await windowManager.isVisible());
      await trayManager.popUpContextMenu();
    } on Object catch (error, stackTrace) {
      _log.severeWithMetadata(
        'Failed to open tray context menu',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _setContextMenu({required bool isWindowVisible}) {
    return trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: _showWindowKey,
            label: isWindowVisible ? 'Hide' : 'Show',
          ),
          MenuItem(key: _checkTrackedAnimeKey, label: 'Check tracked anime'),
          MenuItem.separator(),
          MenuItem(key: _quitKey, label: 'Quit'),
        ],
      ),
    );
  }

  Future<void> _runTrackedAnimeCheck() async {
    final checkTrackedAnime = _checkTrackedAnime;
    if (checkTrackedAnime == null) {
      _log.warning('Tracked-anime check requested before its handler was set');
      return;
    }
    try {
      await checkTrackedAnime();
      _log.info('Tracked-anime check request completed');
    } on Object catch (error, stackTrace) {
      _log.severeWithMetadata(
        'Tracked-anime check from tray failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void onTrayIconMouseDown() {
    _log.info('Tray icon primary click received');
    unawaited(_toggleWindowVisibility());
  }

  @override
  void onTrayIconRightMouseDown() {
    _log.info('Tray icon secondary click received; opening context menu');
    unawaited(_showContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    _log.infoWithMetadata(
      'Tray menu item clicked',
      metadata: {'key': menuItem.key, 'label': menuItem.label},
    );
    switch (menuItem.key) {
      case _showWindowKey:
        unawaited(_toggleWindowVisibility());
        return;
      case _checkTrackedAnimeKey:
        unawaited(_runTrackedAnimeCheck());
        return;
      case _quitKey:
        unawaited(_quit());
        return;
    }
  }

  Future<void> _quit() async {
    if (_quitting) {
      _log.info('Ignoring duplicate explicit quit request');
      return;
    }
    _quitting = true;
    try {
      _log.info('Explicit quit requested from tray menu');
      await trayManager.destroy();
      await windowManager.setPreventClose(false);
      _log.info(
        'Tray destroyed and close prevention disabled; destroying window',
      );
      await windowManager.destroy();
    } on Object catch (error, stackTrace) {
      _log.severeWithMetadata(
        'Explicit tray quit failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
