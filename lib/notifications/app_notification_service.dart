import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/persistence/app_persistence.dart';
import 'package:senpwai/ui/components/toast.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';
import 'package:window_manager/window_manager.dart' as window_manager;

const backgroundNotificationActionPortName =
    'senpwai.background_notification_action';
const downloadsNotificationRoute = '/downloads';

enum NotificationActionKind { open, pause, resume, cancel }

enum NotificationActionTargetType { download, batch }

class NotificationActionEvent {
  final NotificationActionKind kind;
  final NotificationActionTargetType? targetType;
  final String? targetId;

  const NotificationActionEvent({
    required this.kind,
    required this.targetType,
    required this.targetId,
  });
}

class AppNotificationService {
  AppNotificationService._();

  static final AppNotificationService instance = AppNotificationService._();

  static const actionPause = 'download.pause';
  static const actionResume = 'download.resume';
  static const actionCancel = 'download.cancel';
  static const _downloadProgressChannelId = 'download_progress';
  static const _downloadEventsChannelId = 'download_events';
  static const _defaultWindowsProgressId = 'download-progress';
  static const _windowsProgressTitleBinding = 'download-title';
  static const _windowsProgressBodyBinding = 'download-body';
  static const _windowsProgressStatusBinding = 'download-status';
  static const _windowsInitialProgressUpdateDelay = Duration(seconds: 10);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final _actionController =
      StreamController<NotificationActionEvent>.broadcast();
  final List<NotificationActionEvent> _pendingActionEvents = [];
  final Map<int, DateTime> _windowsProgressShownAt = {};
  _NotificationPresentationObserver? _presentationObserver;
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;

  Stream<NotificationActionEvent> get actionStream => _actionController.stream;

  List<NotificationActionEvent> takePendingActionEvents() {
    final events = List<NotificationActionEvent>.from(_pendingActionEvents);
    _pendingActionEvents.clear();
    return events;
  }

  void emitActionEvent(NotificationActionEvent event) {
    _emitActionEvent(event);
  }

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('ic_notification');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    final linux = LinuxInitializationSettings(
      defaultActionName: 'Open Senpwai',
      defaultIcon: AssetsLinuxIcon('images/senpwai-icon.png'),
    );
    final windows = WindowsInitializationSettings(
      appName: 'Senpwai',
      appUserModelId: 'Senpwai.Senpwai.App',
      guid: '4e1e4bb4-6c3d-4b70-92f4-c89d77019110',
      iconPath: _windowsNotificationIconPath,
    );

    await _plugin.initialize(
      settings: InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
        linux: linux,
        windows: windows,
      ),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          handleBackgroundNotificationResponse,
    );
    await _captureLaunchNotificationResponse();
    _initialized = true;
  }

  Future<void> configurePresentation({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;
    final observer =
        _presentationObserver ?? _NotificationPresentationObserver();
    _presentationObserver = observer;
    await observer.initialize();
  }

  Future<void> syncSettings(AppSettingsNotifier notifier) async {
    final settings = notifier.currentState.notifications;
    if (!settings.enabled || settings.permissionDenied) return;
    final granted = await requestRuntimePermissions();
    if (!granted) {
      await notifier.setNotificationPermissionDenied(true);
    }
  }

  Future<void> setEnabledFromSettings({
    required AppSettingsNotifier notifier,
    required bool enabled,
  }) async {
    if (!enabled) {
      await notifier.setNotificationsEnabled(false);
      return;
    }

    final granted = await requestRuntimePermissions();
    if (granted) {
      await notifier.setNotificationPermissionDenied(false);
      await notifier.setNotificationsEnabled(true);
      return;
    }

    await notifier.setNotificationPermissionDenied(true);
  }

  Future<void> showDownloadProgress({
    required int id,
    required String title,
    required String body,
    required double progress,
    required bool paused,
    required NotificationActionTargetType targetType,
    required String targetId,
  }) async {
    await initialize();
    if (!await notificationsAllowed()) return;
    final clampedProgress = progress.clamp(0, 1).toDouble();
    final percent = (clampedProgress * 100).round().clamp(0, 100);
    final status = paused ? 'Paused' : 'Downloading';
    final payload = _payload(targetType, targetId);
    final accentColor = _notificationAccentColor();

    if (Platform.isWindows) {
      final shownAt = _windowsProgressShownAt[id];
      if (shownAt != null &&
          DateTime.now().difference(shownAt) <
              _windowsInitialProgressUpdateDelay) {
        return;
      }
      final progressBar = WindowsProgressBar(
        id: _defaultWindowsProgressId,
        status: '{$_windowsProgressStatusBinding}',
        value: clampedProgress,
        label: '$percent%',
      );
      final bindings = <String, String>{
        _windowsProgressTitleBinding: title,
        _windowsProgressBodyBinding: body,
        _windowsProgressStatusBinding: status,
        '$_defaultWindowsProgressId-progressValue': clampedProgress.toString(),
        '$_defaultWindowsProgressId-progressString': '$percent%',
      };
      final windows = _plugin
          .resolvePlatformSpecificImplementation<
            FlutterLocalNotificationsWindows
          >();
      final result = await windows?.updateBindings(id: id, bindings: bindings);
      if (result == NotificationUpdateResult.success) return;
      if (shownAt != null && result == NotificationUpdateResult.notFound) {
        return;
      }
      if (shownAt != null) return;

      await _plugin.show(
        id: id,
        title: '{$_windowsProgressTitleBinding}',
        body: '{$_windowsProgressBodyBinding}',
        notificationDetails: NotificationDetails(
          windows: WindowsNotificationDetails(
            progressBars: [progressBar],
            bindings: bindings,
          ),
        ),
        payload: payload,
      );
      _windowsProgressShownAt[id] = DateTime.now();
      return;
    }

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _downloadProgressChannelId,
          'Download progress',
          channelDescription: 'Ongoing Senpwai download progress.',
          channelShowBadge: false,
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: 100,
          progress: percent,
          ongoing: !paused,
          autoCancel: false,
          color: accentColor,
          colorized: true,
          category: AndroidNotificationCategory.progress,
        ),
        windows: WindowsNotificationDetails(
          progressBars: [
            WindowsProgressBar(
              id: _defaultWindowsProgressId,
              title: title,
              status: status,
              value: clampedProgress,
              label: '$percent%',
            ),
          ],
        ),
        linux: LinuxNotificationDetails(
          urgency: paused
              ? LinuxNotificationUrgency.normal
              : LinuxNotificationUrgency.low,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> showDownloadCompleted({
    required int id,
    required String title,
    required String body,
  }) {
    return showUserEvent(id: id, title: title, body: body);
  }

  Future<void> showDownloadFailed({
    required int id,
    required String title,
    required String body,
  }) {
    return showUserEvent(
      id: id,
      title: title,
      body: body,
      level: UserEventLevel.error,
    );
  }

  Future<void> showUserEvent({
    required int id,
    required String title,
    required String body,
    UserEventLevel level = UserEventLevel.info,
  }) async {
    final context = _navigatorKey?.currentContext;
    if (context != null &&
        (_presentationObserver?.shouldUseToast ?? _fallbackShouldUseToast)) {
      _showToast(context, title: title, body: body, level: level);
      return;
    }
    await showEvent(id: id, title: title, body: body);
  }

  Future<void> showEvent({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();
    if (!await notificationsAllowed()) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _downloadEventsChannelId,
          'Download updates',
          channelDescription: 'Senpwai download completion and error updates.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        windows: const WindowsNotificationDetails(),
      ),
      payload: 'downloads',
    );
  }

  Future<void> cancel(int id) async {
    await initialize();
    _windowsProgressShownAt.remove(id);
    await _plugin.cancel(id: id);
  }

  Future<bool> notificationsAllowed() async {
    final settings = AppPersistence.settings.notifications;
    if (!settings.enabled || settings.permissionDenied) return false;
    if (!Platform.isAndroid) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? true;
  }

  Future<bool> requestRuntimePermissions() async {
    await initialize();
    if (!Platform.isAndroid) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    _emitActionEvent(_eventFromResponse(response));
  }

  Future<void> _captureLaunchNotificationResponse() async {
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp != true || response == null) {
      return;
    }
    _pendingActionEvents.add(_eventFromResponse(response));
  }

  NotificationActionEvent _eventFromResponse(NotificationResponse response) {
    final target = _parseNotificationPayload(response.payload);
    return NotificationActionEvent(
      kind: _actionKindFromId(response.actionId),
      targetType: target?.type,
      targetId: target?.id,
    );
  }

  void _emitActionEvent(NotificationActionEvent event) {
    if (!_actionController.hasListener) {
      _pendingActionEvents.add(event);
      return;
    }
    _actionController.add(event);
  }

  String _payload(NotificationActionTargetType type, String id) {
    final prefix = switch (type) {
      NotificationActionTargetType.download => 'download',
      NotificationActionTargetType.batch => 'batch',
    };
    return '$prefix:$id';
  }

  Color _notificationAccentColor() {
    final settings = AppPersistence.settings;
    final colors = settings.appearance.themePreset.toTheme().colors;
    final isDark = switch (settings.appearance.brightnessMode) {
      BrightnessMode.dark => true,
      BrightnessMode.light => false,
      BrightnessMode.system =>
        PlatformDispatcher.instance.platformBrightness == Brightness.dark,
    };
    return isDark ? colors.dark.primary : colors.light.primary;
  }

  String? get _windowsNotificationIconPath {
    if (!Platform.isWindows) return null;
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    return '$executableDirectory${Platform.pathSeparator}data'
        '${Platform.pathSeparator}flutter_assets${Platform.pathSeparator}assets'
        '${Platform.pathSeparator}images${Platform.pathSeparator}'
        'senpwai-icon.png';
  }

  bool get _fallbackShouldUseToast =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  void _showToast(
    BuildContext context, {
    required String title,
    required String body,
    required UserEventLevel level,
  }) {
    switch (level) {
      case UserEventLevel.info:
        AppToast.showInfoDeferred(context, title: title, description: body);
      case UserEventLevel.warning:
        AppToast.showWarningDeferred(context, title: title, description: body);
      case UserEventLevel.error:
        AppToast.showErrorDeferred(context, title: title, description: body);
    }
  }
}

enum UserEventLevel { info, warning, error }

class _NotificationPresentationObserver extends WidgetsBindingObserver
    with window_manager.WindowListener {
  var _lifecycleState =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  var _desktopFocused = true;
  var _desktopVisible = true;
  var _desktopMinimized = false;
  var _initialized = false;

  bool get shouldUseToast {
    if (_lifecycleState != AppLifecycleState.resumed) return false;
    if (Platform.isAndroid || Platform.isIOS) return true;
    return _desktopFocused && _desktopVisible && !_desktopMinimized;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    WidgetsBinding.instance.addObserver(this);
    if (!Platform.isAndroid && !Platform.isIOS) {
      await window_manager.windowManager.ensureInitialized();
      window_manager.windowManager.addListener(this);
      _desktopFocused = await window_manager.windowManager.isFocused();
      _desktopVisible = await window_manager.windowManager.isVisible();
      _desktopMinimized = await window_manager.windowManager.isMinimized();
    }
    _initialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  @override
  void onWindowFocus() {
    _desktopFocused = true;
  }

  @override
  void onWindowBlur() {
    _desktopFocused = false;
  }

  @override
  void onWindowMinimize() {
    _desktopMinimized = true;
  }

  @override
  void onWindowRestore() {
    _desktopMinimized = false;
    _desktopVisible = true;
  }
}

@pragma('vm:entry-point')
void handleBackgroundNotificationResponse(NotificationResponse response) {
  DartPluginRegistrant.ensureInitialized();
  final event = notificationActionEventFromResponse(response);
  if (event.kind == NotificationActionKind.open) return;
  final message = {
    'kind': event.kind.name,
    'targetType': event.targetType?.name,
    'targetId': event.targetId,
  };
  final port = IsolateNameServer.lookupPortByName(
    backgroundNotificationActionPortName,
  );
  if (port != null) {
    port.send(message);
  }
}

NotificationActionKind _actionKindFromId(String? actionId) {
  return switch (actionId) {
    AppNotificationService.actionPause => NotificationActionKind.pause,
    AppNotificationService.actionResume => NotificationActionKind.resume,
    AppNotificationService.actionCancel => NotificationActionKind.cancel,
    _ => NotificationActionKind.open,
  };
}

NotificationActionEvent notificationActionEventFromResponse(
  NotificationResponse response,
) {
  final target = _parseNotificationPayload(response.payload);
  return NotificationActionEvent(
    kind: _actionKindFromId(response.actionId),
    targetType: target?.type,
    targetId: target?.id,
  );
}

class _NotificationPayloadTarget {
  final NotificationActionTargetType type;
  final String id;

  const _NotificationPayloadTarget({required this.type, required this.id});
}

_NotificationPayloadTarget? _parseNotificationPayload(String? payload) {
  if (payload == null) return null;
  final separator = payload.indexOf(':');
  if (separator <= 0 || separator == payload.length - 1) return null;
  final type = switch (payload.substring(0, separator)) {
    'download' => NotificationActionTargetType.download,
    'batch' => NotificationActionTargetType.batch,
    _ => null,
  };
  if (type == null) return null;
  return _NotificationPayloadTarget(
    type: type,
    id: payload.substring(separator + 1),
  );
}

void unawaitedNotification(Future<void> future) {
  unawaited(
    future.catchError((Object error, StackTrace stackTrace) {
      if (kDebugMode) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'senpwai.notifications',
          ),
        );
      }
    }),
  );
}
