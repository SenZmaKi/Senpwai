import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:senpwai/settings/models.dart';
import 'package:senpwai/shared/persistence/window_state_repository.dart';
import 'package:window_manager/window_manager.dart';

bool get supportsWindowCustomization =>
    !kIsWeb && !Platform.isAndroid && !Platform.isIOS;

class WindowManager with WindowListener {
  static WindowManager? _instance;
  static const _minimumVisibleExtent = 64.0;

  Timer? _saveBoundsTimer;
  bool _ready = false;
  bool _savingBounds = false;
  bool _saveAgain = false;
  bool _mobileFullScreen = false;
  WindowStateRepository? _stateRepository;
  Future<void> Function()? _closeHandler;

  static WindowManager getInstance() {
    _instance ??= WindowManager();
    return _instance!;
  }

  Future<void> init(
    WindowPreferences preferences,
    WindowStateRepository stateRepository,
  ) async {
    if (!supportsWindowCustomization) return;
    _stateRepository = stateRepository;
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    // The tray controller enables close prevention only after it has created
    // a reachable tray icon and installed the close handler.
    await windowManager.setPreventClose(false);
    final savedBounds = await stateRepository.load();
    final restoredBounds = await _restorableBounds(savedBounds);
    final windowOptions = WindowOptions(
      alwaysOnTop: preferences.alwaysOnTop,
      center: savedBounds != null && restoredBounds == null,
      fullScreen: preferences.startFullScreen,
      title: 'Senpwai',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (restoredBounds != null &&
          !preferences.startMaximized &&
          !preferences.startFullScreen) {
        await windowManager.setBounds(restoredBounds);
      }
      if (preferences.startMaximized && !preferences.startFullScreen) {
        await windowManager.maximize();
      }
    });
  }

  Future<void> reveal() async {
    if (!supportsWindowCustomization || _ready) return;
    await focus();
    _ready = true;
  }

  Future<void> applyAlwaysOnTop(bool alwaysOnTop) async {
    if (!supportsWindowCustomization) return;
    await windowManager.setAlwaysOnTop(alwaysOnTop);
  }

  Future<void> toggleFullScreen() async {
    if (supportsWindowCustomization) {
      await windowManager.setFullScreen(!(await windowManager.isFullScreen()));
      return;
    }
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    _mobileFullScreen = !_mobileFullScreen;
    await SystemChrome.setEnabledSystemUIMode(
      _mobileFullScreen
          ? SystemUiMode.immersiveSticky
          : SystemUiMode.edgeToEdge,
    );
  }

  Future<void> focus() async {
    if (!supportsWindowCustomization) return;
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> configureCloseHandler(Future<void> Function() onClose) async {
    if (!supportsWindowCustomization) return;
    _closeHandler = onClose;
    await windowManager.setPreventClose(true);
  }

  Future<void> closeWindow() async {
    if (!supportsWindowCustomization) return;
    final closeHandler = _closeHandler;
    _closeHandler = null;
    await windowManager.setPreventClose(false);
    try {
      await windowManager.close();
    } finally {
      _closeHandler = closeHandler;
      await windowManager.setPreventClose(closeHandler != null);
    }
  }

  @override
  void onWindowClose() {
    final closeHandler = _closeHandler;
    if (closeHandler != null) {
      unawaited(closeHandler());
    }
  }

  @override
  void onWindowMove() => _scheduleBoundsSave();

  @override
  void onWindowMoved() => _saveBoundsNow();

  @override
  void onWindowResize() => _scheduleBoundsSave();

  @override
  void onWindowResized() => _saveBoundsNow();

  @override
  void onWindowUnmaximize() => _scheduleBoundsSave();

  @override
  void onWindowLeaveFullScreen() => _scheduleBoundsSave();

  void _scheduleBoundsSave() {
    if (!_ready || _stateRepository == null) return;
    _saveBoundsTimer?.cancel();
    _saveBoundsTimer = Timer(
      const Duration(milliseconds: 500),
      _saveNormalBounds,
    );
  }

  void _saveBoundsNow() {
    if (!_ready || _stateRepository == null) return;
    _saveBoundsTimer?.cancel();
    unawaited(_saveNormalBounds());
  }

  Future<void> _saveNormalBounds() async {
    if (_savingBounds) {
      _saveAgain = true;
      return;
    }
    final repository = _stateRepository;
    if (!_ready || repository == null) return;

    _savingBounds = true;
    try {
      if (await windowManager.isMaximized() ||
          await windowManager.isFullScreen() ||
          await windowManager.isMinimized()) {
        return;
      }
      final bounds = await windowManager.getBounds();
      if (!bounds.left.isFinite ||
          !bounds.top.isFinite ||
          !bounds.width.isFinite ||
          !bounds.height.isFinite ||
          bounds.width <= 0 ||
          bounds.height <= 0) {
        return;
      }
      await repository.save(
        WindowBounds(
          x: bounds.left,
          y: bounds.top,
          width: bounds.width,
          height: bounds.height,
        ),
      );
    } finally {
      _savingBounds = false;
      if (_saveAgain) {
        _saveAgain = false;
        _scheduleBoundsSave();
      }
    }
  }

  Future<Rect?> _restorableBounds(WindowBounds? saved) async {
    if (saved == null) return null;
    final requested = Rect.fromLTWH(
      saved.x,
      saved.y,
      saved.width,
      saved.height,
    );
    final displays = await screenRetriever.getAllDisplays();
    Rect? bestFrame;
    var largestVisibleArea = 0.0;
    for (final display in displays) {
      final frame = Rect.fromLTWH(
        display.visiblePosition?.dx ?? 0,
        display.visiblePosition?.dy ?? 0,
        (display.visibleSize ?? display.size).width,
        (display.visibleSize ?? display.size).height,
      );
      final intersection = requested.intersect(frame);
      final visibleArea =
          intersection.width.clamp(0, double.infinity) *
          intersection.height.clamp(0, double.infinity);
      if (visibleArea > largestVisibleArea) {
        largestVisibleArea = visibleArea.toDouble();
        bestFrame = frame;
      }
    }
    if (bestFrame == null ||
        largestVisibleArea < _minimumVisibleExtent * _minimumVisibleExtent) {
      return null;
    }

    final width = requested.width.clamp(_minimumVisibleExtent, bestFrame.width);
    final height = requested.height.clamp(
      _minimumVisibleExtent,
      bestFrame.height,
    );
    final left = requested.left.clamp(bestFrame.left, bestFrame.right - width);
    final top = requested.top.clamp(bestFrame.top, bestFrame.bottom - height);
    return Rect.fromLTWH(left, top, width, height);
  }
}
