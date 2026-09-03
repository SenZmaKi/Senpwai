import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/ui/shared/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart' show windowManager;

final _log = Logger('senpwai.ui.desktop_tray');

enum DesktopExitRequest { windowClose, trayQuit, systemQuit }

/// Owns the desktop tray lifecycle and keeps the window reachable after close.
class DesktopTrayController with TrayListener {
  DesktopTrayController._();

  static final instance = DesktopTrayController._();

  static const _showWindowKey = 'show_senpwai';
  static const _checkTrackedAnimeKey = 'check_tracked_anime';
  static const _quitKey = 'quit';
  static const _terminationChannel = MethodChannel('senpwai/app_termination');
  static const _menuBarModeChannel = MethodChannel('senpwai/menu_bar_mode');
  static const _windowReopenChannel = MethodChannel('senpwai/window_reopen');

  Future<void> Function()? _checkTrackedAnime;
  Future<bool> Function(DesktopExitRequest request)? _onExitRequested;
  bool _initialized = false;
  bool _quitting = false;

  Future<void> initialize({
    required Future<void> Function() onCheckTrackedAnime,
    required Future<bool> Function(DesktopExitRequest request) onExitRequested,
  }) async {
    if (!supportsWindowCustomization) return;
    _checkTrackedAnime = onCheckTrackedAnime;
    _onExitRequested = onExitRequested;
    if (_initialized) return;

    try {
      trayManager.addListener(this);
      await trayManager.setIcon(_iconPath);
      if (!Platform.isLinux) {
        await trayManager.setToolTip('Senpwai');
      }
      await _setContextMenu(isWindowVisible: await windowManager.isVisible());
      await WindowManager.getInstance().configureCloseHandler(_requestClose);
      _terminationChannel.setMethodCallHandler(_handleTerminationRequest);
      _windowReopenChannel.setMethodCallHandler(_handleWindowReopen);
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_refreshContextMenu());
      });
    } on Object catch (error, stackTrace) {
      trayManager.removeListener(this);
      _log.severeWithMetadata(
        'Tray initialization failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> minimizeToTray() => _hideWindow();

  Future<void> closeWindow() => WindowManager.getInstance().closeWindow();

  Future<void> quitApp() async {
    if (_quitting) return;
    _quitting = true;
    try {
      await trayManager.destroy();
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } on Object catch (error, stackTrace) {
      _log.severeWithMetadata(
        'Explicit tray quit failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
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
    if (_quitting) return;
    try {
      await windowManager.hide();
      await _setMenuBarMode(true);
      await _setContextMenu(isWindowVisible: false);
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
      await _setMenuBarMode(false);
      await WindowManager.getInstance().focus();
      await _setContextMenu(isWindowVisible: true);
    } on Object catch (error, stackTrace) {
      _log.severeWithMetadata(
        'Failed to show window from tray',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _setMenuBarMode(bool enabled) async {
    if (!Platform.isMacOS) return;
    await _menuBarModeChannel.invokeMethod<void>('setEnabled', {
      'enabled': enabled,
    });
  }

  Future<void> _showContextMenu() async {
    try {
      await _refreshContextMenu();
      await trayManager.popUpContextMenu();
    } on Object catch (error, stackTrace) {
      _log.severeWithMetadata(
        'Failed to open tray context menu',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _refreshContextMenu() {
    return windowManager.isVisible().then(
      (isWindowVisible) => _setContextMenu(isWindowVisible: isWindowVisible),
    );
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
    unawaited(_toggleWindowVisibility());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(_showContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _showWindowKey:
        unawaited(_toggleWindowVisibility());
        return;
      case _checkTrackedAnimeKey:
        unawaited(_runTrackedAnimeCheck());
        return;
      case _quitKey:
        unawaited(_requestExit(DesktopExitRequest.trayQuit));
        return;
    }
  }

  Future<void> _requestClose() async {
    await _requestExit(DesktopExitRequest.windowClose);
  }

  Future<bool> _handleTerminationRequest(MethodCall call) async {
    if (call.method != 'requestQuit') {
      throw MissingPluginException('Unsupported method: ${call.method}');
    }
    if (_quitting) return true;
    return _requestExit(DesktopExitRequest.systemQuit);
  }

  Future<void> _handleWindowReopen(MethodCall call) async {
    if (call.method != 'restoreWindow') {
      throw MissingPluginException('Unsupported method: ${call.method}');
    }
    if (!_quitting) await _showWindow();
  }

  Future<bool> _requestExit(DesktopExitRequest request) async {
    final onExitRequested = _onExitRequested;
    if (onExitRequested == null) {
      await quitApp();
      return false;
    }
    return onExitRequested(request);
  }
}
