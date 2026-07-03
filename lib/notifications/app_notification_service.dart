import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/persistence/app_persistence.dart';
import 'package:senpwai/ui/shared/theme/theme.dart';

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

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final _actionController =
      StreamController<NotificationActionEvent>.broadcast();
  final List<NotificationActionEvent> _pendingActionEvents = [];
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
    const windows = WindowsInitializationSettings(
      appName: 'Senpwai',
      appUserModelId: 'Senpwai.Senpwai.App',
      guid: '4e1e4bb4-6c3d-4b70-92f4-c89d77019110',
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
    return showEvent(id: id, title: title, body: body);
  }

  Future<void> showDownloadFailed({
    required int id,
    required String title,
    required String body,
  }) {
    return showEvent(id: id, title: title, body: body);
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
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _downloadEventsChannelId,
          'Download updates',
          channelDescription: 'Senpwai download completion and error updates.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: 'downloads',
    );
  }

  Future<void> cancel(int id) async {
    await initialize();
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
