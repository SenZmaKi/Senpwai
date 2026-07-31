import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/downloads/in_process_runtime.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/runtime_codec.dart';
import 'package:senpwai/notifications/app_notification_service.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/user_agents.dart';
import 'package:senpwai/shared/persistence/app_paths.dart';
import 'package:senpwai/ui/pages/settings_page/settings_formatters.dart';

typedef _CommandPayload = Map<String, Object?>;

final _log = Logger('senpwai.downloads.android_foreground_runtime');

class AndroidForegroundDownloadRuntime implements DownloadRuntime {
  static const _summaryNotificationId = 2601;
  static const _progressChannelId = 'senpwai_download_service';
  static const _eventsChannelId = 'download_events';
  static const _actionPause = 'download.pause';
  static const _actionResume = 'download.resume';
  static const _actionCancel = 'download.cancel';

  final DownloadRuntimeErrorHandler onError;
  final _stateController = StreamController<DownloadManagerState>.broadcast();
  final _pendingRequests = <String, Completer<Object?>>{};
  int _maxDownloadBytesPerSecond;
  String _downloadUserAgent;
  TorrentPreferences _torrentSettings;
  NotificationPreferences _notificationSettings;
  var _stateSnapshot = const DownloadManagerState();
  var _requestCounter = 0;

  static bool _initialized = false;

  AndroidForegroundDownloadRuntime({
    required int initialMaxDownloadBytesPerSecond,
    required String downloadUserAgent,
    required TorrentPreferences initialTorrentSettings,
    required NotificationPreferences initialNotificationSettings,
    required this.onError,
  }) : _maxDownloadBytesPerSecond = initialMaxDownloadBytesPerSecond,
       _downloadUserAgent = downloadUserAgent,
       _torrentSettings = initialTorrentSettings,
       _notificationSettings = initialNotificationSettings {
    if (Platform.isAndroid) {
      _initializeForegroundTask();
      FlutterForegroundTask.addTaskDataCallback(_onTaskData);
      unawaited(_attachToRunningService());
    }
  }

  @override
  DownloadManagerState get currentState => _stateSnapshot;

  @override
  Stream<DownloadManagerState> get stateStream => _stateController.stream;

  @override
  Future<EnqueuedDownloadsResult> enqueueBatch(
    PreparedDownloadBatch batch,
  ) async {
    final result = await _sendCommand('enqueueBatch', {
      'batch': DownloadRuntimeCodec.encodePreparedBatch(batch),
    });
    return DownloadRuntimeCodec.decodeEnqueuedResult(_map(result));
  }

  @override
  Future<void> pause(String id) => _sendVoidCommand('pause', {'id': id});

  @override
  Future<void> resume(String id) => _sendVoidCommand('resume', {'id': id});

  @override
  Future<void> cancel(String id) => _sendVoidCommand('cancel', {'id': id});

  @override
  Future<void> pauseBatch(String batchId) =>
      _sendVoidCommand('pauseBatch', {'batchId': batchId});

  @override
  Future<void> resumeBatch(String batchId) =>
      _sendVoidCommand('resumeBatch', {'batchId': batchId});

  @override
  Future<void> cancelBatch(String batchId) =>
      _sendVoidCommand('cancelBatch', {'batchId': batchId});

  @override
  void reorder(int oldIndex, int newIndex) {
    unawaited(
      _sendVoidCommand('reorder', {'oldIndex': oldIndex, 'newIndex': newIndex}),
    );
  }

  @override
  void reorderBatch(int oldIndex, int newIndex) {
    unawaited(
      _sendVoidCommand('reorderBatch', {
        'oldIndex': oldIndex,
        'newIndex': newIndex,
      }),
    );
  }

  @override
  void reorderBatchItem(String batchId, int oldIndex, int newIndex) {
    unawaited(
      _sendVoidCommand('reorderBatchItem', {
        'batchId': batchId,
        'oldIndex': oldIndex,
        'newIndex': newIndex,
      }),
    );
  }

  @override
  void clearHistory() {
    unawaited(_sendVoidCommand('clearHistory', const {}));
  }

  @override
  void dismiss(String id) {
    unawaited(_sendVoidCommand('dismiss', {'id': id}));
  }

  @override
  void seedMockDownloads() {
    unawaited(_sendVoidCommand('seedMockDownloads', const {}));
  }

  @override
  void updateHttpDownloadSettings({
    required int maxBytesPerSecond,
    required String userAgent,
  }) {
    _maxDownloadBytesPerSecond = maxBytesPerSecond;
    _downloadUserAgent = userAgent;
    unawaited(_sendSettingsIfRunning());
  }

  @override
  void updateTorrentSettings(TorrentPreferences settings) {
    _torrentSettings = settings;
    unawaited(_sendSettingsIfRunning());
  }

  @override
  void updateNotificationSettings(NotificationPreferences settings) {
    _notificationSettings = settings;
    unawaited(_sendSettingsIfRunning());
  }

  Future<void> _sendSettingsIfRunning() async {
    if (!Platform.isAndroid || !await FlutterForegroundTask.isRunningService) {
      return;
    }
    _sendCurrentSettings();
  }

  Future<void> _attachToRunningService() async {
    if (!Platform.isAndroid || !await FlutterForegroundTask.isRunningService) {
      return;
    }
    _log.info('Attaching to running Android download foreground service');
    try {
      await _sendCommand(
        'syncState',
        const {},
        startIfNeeded: false,
        timeout: const Duration(seconds: 5),
      );
      _sendCurrentSettings();
    } on Object catch (error, stackTrace) {
      _log.warningWithMetadata(
        'Failed to sync state from Android download foreground service',
        metadata: {'error': '$error', 'stackTrace': '$stackTrace'},
      );
    }
  }

  void _sendCurrentSettings() {
    _sendUntrackedCommand('updateHttpDownloadSettings', {
      'maxBytesPerSecond': _maxDownloadBytesPerSecond,
      'userAgent': _downloadUserAgent,
    });
    _sendUntrackedCommand('updateTorrentSettings', {
      'settings': DownloadRuntimeCodec.encodeTorrentSettings(_torrentSettings),
    });
    _sendUntrackedCommand('updateNotificationSettings', {
      'settings': _encodeNotificationSettings(_notificationSettings),
    });
  }

  @override
  Future<void> dispose() async {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Download runtime detached.'));
      }
    }
    _pendingRequests.clear();
    await _stateController.close();
  }

  void _initializeForegroundTask() {
    if (_initialized) return;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _progressChannelId,
        channelName: 'Download progress',
        channelDescription: 'Ongoing Senpwai download progress.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        showBadge: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
    _initialized = true;
  }

  Future<bool> _ensureService() async {
    if (!Platform.isAndroid) return false;
    if (await FlutterForegroundTask.isRunningService) return false;
    final result = await FlutterForegroundTask.startService(
      serviceId: _summaryNotificationId,
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: 'Senpwai downloads',
      notificationText: 'Preparing downloads...',
      notificationIcon: const NotificationIcon(
        metaDataName: 'com.senpwai.download_notification_icon',
      ),
      notificationProgress: const NotificationProgress(
        max: 0,
        progress: 0,
        indeterminate: true,
      ),
      notificationButtons: const [
        NotificationButton(id: _actionPause, text: 'Pause'),
        NotificationButton(id: _actionCancel, text: 'Cancel'),
      ],
      notificationInitialRoute: downloadsNotificationRoute,
      callback: startDownloadForegroundTask,
    );
    if (result case ServiceRequestFailure(:final error)) {
      throw StateError('Failed to start Android download service: $error');
    }
    return true;
  }

  Future<void> _sendVoidCommand(String type, _CommandPayload payload) async {
    await _sendCommand(type, payload);
  }

  Future<Object?> _sendCommand(
    String type,
    _CommandPayload payload, {
    bool startIfNeeded = true,
    Duration? timeout,
  }) async {
    final started = startIfNeeded ? await _ensureService() : false;
    if (!startIfNeeded && !await FlutterForegroundTask.isRunningService) {
      return null;
    }
    if (started) {
      _sendCurrentSettings();
    }
    final requestId = _nextRequestId();
    final completer = Completer<Object?>();
    _pendingRequests[requestId] = completer;
    FlutterForegroundTask.sendDataToTask({
      'kind': 'command',
      'requestId': requestId,
      'type': type,
      'payload': payload,
    });
    final future = completer.future;
    if (timeout == null) return future;
    return future.timeout(
      timeout,
      onTimeout: () {
        _pendingRequests.remove(requestId);
        throw TimeoutException('Timed out waiting for download command $type.');
      },
    );
  }

  void _sendUntrackedCommand(String type, _CommandPayload payload) {
    FlutterForegroundTask.sendDataToTask({
      'kind': 'command',
      'requestId': '',
      'type': type,
      'payload': payload,
    });
  }

  void _onTaskData(Object data) {
    final message = _mapString(data);
    switch (_string(message['kind'])) {
      case 'state':
        final next = DownloadRuntimeCodec.decodeState(_map(message['state']));
        _stateSnapshot = next;
        if (!_stateController.isClosed) _stateController.add(next);
      case 'response':
        _onResponse(message);
      case 'error':
        onError(
          title: _string(message['title']),
          description: _string(message['description']),
          copyPayload: _stringOrNull(message['copyPayload']),
        );
      case 'notificationAction':
        AppNotificationService.instance.emitActionEvent(
          const NotificationActionEvent(
            kind: NotificationActionKind.open,
            targetType: NotificationActionTargetType.batch,
            targetId: null,
          ),
        );
    }
  }

  void _onResponse(Map<String, Object?> message) {
    final requestId = message['requestId'];
    if (requestId is! String) return;
    final completer = _pendingRequests.remove(requestId);
    if (completer == null || completer.isCompleted) return;
    final error = message['error'];
    if (error is String && error.isNotEmpty) {
      completer.completeError(StateError(error));
    } else {
      completer.complete(message['result']);
    }
  }

  String _nextRequestId() {
    _requestCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_requestCounter';
  }
}

@pragma('vm:entry-point')
void startDownloadForegroundTask() {
  FlutterForegroundTask.setTaskHandler(_DownloadForegroundTaskHandler());
}

class _DownloadForegroundTaskHandler extends TaskHandler {
  static const _minimumNotificationInterval = Duration(milliseconds: 750);
  static const _runtimeReadyTimeout = Duration(seconds: 5);
  static const _terminalNotificationGrace = Duration(milliseconds: 1200);

  final _notifications = FlutterLocalNotificationsPlugin();
  final Set<String> _terminalBatchesNotified = {};
  final Map<String, DownloadQueueStatus> _lastItemStatuses = {};
  InProcessDownloadRuntime? _runtime;
  final _runtimeReady = Completer<InProcessDownloadRuntime>();
  StreamSubscription<DownloadManagerState>? _stateSubscription;
  NotificationPreferences _notificationSettings =
      const NotificationPreferences();
  DateTime? _lastNotificationUpdate;
  _BatchNotificationStatus? _lastForegroundStatus;
  Timer? _idleNotificationTimer;
  var _foregroundNotificationIsTerminal = false;
  var _foregroundServiceStopScheduled = false;
  Future<void> _stateHandling = Future.value();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    DartPluginRegistrant.ensureInitialized();
    setupLogger();
    final paths = await AppPaths.initialize();
    configureFileLogging(paths.logsDirectory);
    _log.infoWithMetadata(
      'Download foreground task started',
      metadata: {
        'timestamp': timestamp.toIso8601String(),
        'starter': '$starter',
      },
    );
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          handleBackgroundNotificationResponse,
    );
    _runtime = InProcessDownloadRuntime(
      downloadUserAgent: getRandomUserAgent(),
      initialMaxDownloadBytesPerSecond: 0,
      initialTorrentSettings: const TorrentPreferences(),
      onError: _sendError,
    );
    if (!_runtimeReady.isCompleted) {
      _runtimeReady.complete(_runtime);
    }
    _stateSubscription = _runtime!.stateStream.listen((state) {
      _sendState(state);
      _stateHandling = _stateHandling
          .then((_) => _handleDownloadState(state))
          .catchError((Object error, StackTrace stackTrace) {
            _log.severeWithMetadata(
              'Failed to handle download foreground state',
              error: error,
              stackTrace: stackTrace,
              metadata: _foregroundStateMetadata(state),
            );
          });
    });
    _sendState(_runtime!.currentState);
    _baselineTerminalState(_runtime!.currentState);
    await _updateForegroundNotification(_runtime!.currentState, force: true);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    final runtime = _runtime;
    if (runtime == null) return;
    _sendState(runtime.currentState);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _log.infoWithMetadata(
      'Download foreground task destroyed',
      metadata: {
        'timestamp': timestamp.toIso8601String(),
        'isTimeout': isTimeout,
      },
    );
    _idleNotificationTimer?.cancel();
    await _stateSubscription?.cancel();
    await _stateHandling;
    await _runtime?.dispose();
  }

  @override
  void onReceiveData(Object data) {
    unawaited(_handleCommand(_mapString(data)));
  }

  @override
  void onNotificationButtonPressed(String id) {
    unawaited(_handleNotificationButtonPressed(id));
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.sendDataToMain(const {'kind': 'notificationAction'});
  }

  Future<void> _handleNotificationButtonPressed(String id) async {
    final runtime = await _waitForRuntime();
    if (runtime == null) return;
    final batchId = runtime.currentState.activeBatchId;
    if (batchId == null) return;
    switch (id) {
      case AndroidForegroundDownloadRuntime._actionPause:
        await _updateForegroundNotification(
          runtime.currentState,
          force: true,
          overrideStatus: _BatchNotificationStatus.pausing,
        );
        await runtime.pauseBatch(batchId);
      case AndroidForegroundDownloadRuntime._actionResume:
        await _updateForegroundNotification(
          runtime.currentState,
          force: true,
          overrideStatus: _BatchNotificationStatus.resuming,
        );
        await runtime.resumeBatch(batchId);
      case AndroidForegroundDownloadRuntime._actionCancel:
        await _updateForegroundNotification(
          runtime.currentState,
          force: true,
          overrideStatus: _BatchNotificationStatus.cancelling,
        );
        await runtime.cancelBatch(batchId);
    }
    await _handleDownloadState(runtime.currentState, force: true);
    unawaited(_refreshForegroundNotificationSoon());
  }

  Future<void> _refreshForegroundNotificationSoon() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final runtime = _runtime;
    if (runtime == null) return;
    await _handleDownloadState(runtime.currentState, force: true);
  }

  Future<void> _handleCommand(Map<String, dynamic> message) async {
    if (_string(message['kind']) != 'command') return;
    final requestId = _string(message['requestId']);
    final type = _string(message['type']);
    final payload = _map(message['payload']);
    final runtime = await _waitForRuntime();
    if (runtime == null) {
      _sendResponse(requestId, error: 'Download runtime did not initialize.');
      return;
    }
    try {
      final Object? result;
      switch (type) {
        case 'enqueueBatch':
          final batch = DownloadRuntimeCodec.decodePreparedBatch(
            _map(payload['batch']),
          );
          result = DownloadRuntimeCodec.encodeEnqueuedResult(
            await runtime.enqueueBatch(batch),
          );
        case 'pause':
          await runtime.pause(_string(payload['id']));
          await _sendAndRenderCurrentState(runtime);
          result = null;
        case 'resume':
          await runtime.resume(_string(payload['id']));
          await _sendAndRenderCurrentState(runtime);
          result = null;
        case 'cancel':
          await runtime.cancel(_string(payload['id']));
          await _sendAndRenderCurrentState(runtime);
          result = null;
        case 'pauseBatch':
          await runtime.pauseBatch(_string(payload['batchId']));
          await _sendAndRenderCurrentState(runtime);
          result = null;
        case 'resumeBatch':
          await runtime.resumeBatch(_string(payload['batchId']));
          await _sendAndRenderCurrentState(runtime);
          result = null;
        case 'cancelBatch':
          await runtime.cancelBatch(_string(payload['batchId']));
          await _sendAndRenderCurrentState(runtime);
          result = null;
        case 'reorder':
          runtime.reorder(_int(payload['oldIndex']), _int(payload['newIndex']));
          result = null;
        case 'reorderBatch':
          runtime.reorderBatch(
            _int(payload['oldIndex']),
            _int(payload['newIndex']),
          );
          result = null;
        case 'reorderBatchItem':
          runtime.reorderBatchItem(
            _string(payload['batchId']),
            _int(payload['oldIndex']),
            _int(payload['newIndex']),
          );
          result = null;
        case 'clearHistory':
          runtime.clearHistory();
          result = null;
        case 'dismiss':
          runtime.dismiss(_string(payload['id']));
          result = null;
        case 'seedMockDownloads':
          runtime.seedMockDownloads();
          result = null;
        case 'updateHttpDownloadSettings':
          runtime.updateHttpDownloadSettings(
            maxBytesPerSecond: _int(payload['maxBytesPerSecond']),
            userAgent: _string(payload['userAgent']),
          );
          result = null;
        case 'updateTorrentSettings':
          runtime.updateTorrentSettings(
            DownloadRuntimeCodec.decodeTorrentSettings(
              _map(payload['settings']),
            ),
          );
          result = null;
        case 'updateNotificationSettings':
          _notificationSettings = _decodeNotificationSettings(
            _map(payload['settings']),
          );
          _baselineTerminalState(runtime.currentState);
          await _updateForegroundNotification(
            runtime.currentState,
            force: true,
          );
          result = null;
        case 'syncState':
          _sendState(runtime.currentState);
          _baselineTerminalState(runtime.currentState);
          await _updateForegroundNotification(
            runtime.currentState,
            force: true,
          );
          result = null;
        default:
          throw UnsupportedError('Unknown download command: $type');
      }
      _sendResponse(requestId, result: result);
    } on Object catch (error, stackTrace) {
      _sendResponse(
        requestId,
        error:
            '$error\n\n${stackTrace.toString().split('\n').take(8).join('\n')}',
      );
    }
  }

  Future<void> _sendAndRenderCurrentState(InProcessDownloadRuntime runtime) {
    final state = runtime.currentState;
    _sendState(state);
    return _handleDownloadState(state, force: true);
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final event = notificationActionEventFromResponse(response);
    if (event.kind != NotificationActionKind.open) return;
  }

  Future<void> _handleDownloadState(
    DownloadManagerState state, {
    bool force = false,
  }) async {
    await _showTerminalNotifications(state);
    await _updateForegroundNotification(
      state,
      force: force || _activeBatchIsTerminal(state),
    );
  }

  Future<void> _updateForegroundNotification(
    DownloadManagerState state, {
    bool force = false,
    _BatchNotificationStatus? overrideStatus,
  }) async {
    final activeBatchId = state.activeBatchId;
    final activeBatch = activeBatchId == null
        ? null
        : _batchById(state, activeBatchId);
    final batchItems = activeBatch == null
        ? const <DownloadQueueItem>[]
        : _itemsForBatch(state, activeBatch);
    final activeItems = batchItems
        .where((item) => !item.status.isTerminal)
        .toList();

    if (activeBatch == null || batchItems.isEmpty) {
      _log.fineWithMetadata(
        'Download foreground notification has no active batch',
        metadata: _foregroundStateMetadata(state),
      );
      await _stopForegroundServiceIfIdle(state);
      return;
    }

    final aggregate = _aggregateProgress(batchItems);
    final status =
        overrideStatus ?? _batchNotificationStatus(batchItems, activeItems);
    final statusChanged = status != _lastForegroundStatus;
    final mustProcessImmediately = statusChanged || status.isTerminal || force;
    final now = DateTime.now();
    final last = _lastNotificationUpdate;
    if (!mustProcessImmediately &&
        last != null &&
        now.difference(last) < _minimumNotificationInterval) {
      _log.fineWithMetadata(
        'Throttling download foreground progress notification update',
        metadata: {
          ..._foregroundStateMetadata(state),
          'status': status.name,
          'percent': aggregate.percent,
        },
      );
      return;
    }
    _lastNotificationUpdate = now;
    _lastForegroundStatus = status;

    _cancelPendingForegroundStop();
    _foregroundNotificationIsTerminal = status.isTerminal;
    if (status.isTerminal) {
      _log.infoWithMetadata(
        'Download foreground notification reached terminal batch state',
        metadata: {
          ..._foregroundStateMetadata(state),
          'status': status.name,
          'percent': aggregate.percent,
          'downloadedBytes': aggregate.downloadedBytes,
          'totalBytes': aggregate.totalBytes,
        },
      );
    }
    await _updateServiceNotification(
      title: activeBatch.title,
      text: _batchProgressBody(batchItems, aggregate, status: status),
      progress: _notificationProgress(aggregate, status),
      buttons: _notificationButtonsForStatus(status),
    );
  }

  Future<void> _showIdleForegroundNotification() {
    _lastForegroundStatus = null;
    return _updateServiceNotification(
      title: 'Senpwai downloads',
      text: 'Download service is ready',
      progress: const NotificationProgress.none(),
      buttons: const [],
    );
  }

  Future<void> _stopForegroundServiceIfIdle(DownloadManagerState state) async {
    if (state.batches.isNotEmpty) {
      _log.fineWithMetadata(
        'Download foreground service kept alive because queued batches remain',
        metadata: _foregroundStateMetadata(state),
      );
      _cancelPendingForegroundStop();
      await _showIdleForegroundNotification();
      return;
    }
    if (_foregroundServiceStopScheduled) {
      _log.fineWithMetadata(
        'Download foreground service stop already scheduled',
        metadata: _foregroundStateMetadata(state),
      );
      return;
    }
    if (!_foregroundNotificationIsTerminal) {
      _log.fineWithMetadata(
        'Download foreground service is idle without a terminal foreground state',
        metadata: _foregroundStateMetadata(state),
      );
      await _showIdleForegroundNotification();
      return;
    }
    _foregroundNotificationIsTerminal = false;
    _foregroundServiceStopScheduled = true;
    _idleNotificationTimer?.cancel();
    _log.infoWithMetadata(
      'Scheduling download foreground service stop',
      metadata: {
        ..._foregroundStateMetadata(state),
        'graceMs': _terminalNotificationGrace.inMilliseconds,
      },
    );
    _idleNotificationTimer = Timer(_terminalNotificationGrace, () {
      unawaited(_stopForegroundService());
    });
  }

  Future<void> _stopForegroundService() async {
    _idleNotificationTimer?.cancel();
    _foregroundServiceStopScheduled = false;
    _lastForegroundStatus = null;
    _log.info('Stopping download foreground service');
    final result = await FlutterForegroundTask.stopService();
    if (result case ServiceRequestSuccess()) {
      _log.info('Download foreground service stop requested successfully');
    } else if (result case ServiceRequestFailure(:final error)) {
      _log.warningWithMetadata(
        'Failed to stop download foreground service',
        metadata: {'error': '$error'},
      );
    }
  }

  void _cancelPendingForegroundStop() {
    _idleNotificationTimer?.cancel();
    _foregroundServiceStopScheduled = false;
  }

  Future<void> _updateServiceNotification({
    required String title,
    required String text,
    required NotificationProgress progress,
    required List<NotificationButton> buttons,
  }) async {
    final result = await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
      notificationIcon: const NotificationIcon(
        metaDataName: 'com.senpwai.download_notification_icon',
      ),
      notificationProgress: progress,
      notificationButtons: buttons,
      notificationInitialRoute: downloadsNotificationRoute,
    );
    if (result case ServiceRequestFailure()) {
      _log.warningWithMetadata(
        'Failed to update download foreground service notification',
        metadata: {'title': title, 'text': text},
      );
    }
  }

  Future<void> _showTerminalNotifications(DownloadManagerState state) async {
    if (!_notificationSettings.enabled ||
        _notificationSettings.permissionDenied) {
      _baselineTerminalState(state);
      return;
    }

    if (_notificationSettings.downloadStyle ==
        DownloadNotificationStyle.episodeCompletion) {
      await _showTerminalEpisodeNotifications(state);
      return;
    }

    await _showTerminalBatchNotifications(state);
  }

  Future<void> _showTerminalBatchNotifications(
    DownloadManagerState state,
  ) async {
    final activeBatchIds = {for (final batch in state.batches) batch.id};
    _terminalBatchesNotified.removeWhere(
      (batchId) => !activeBatchIds.contains(batchId),
    );
    for (final batch in state.batches) {
      if (_terminalBatchesNotified.contains(batch.id)) continue;
      final items = _itemsForBatch(state, batch);
      if (items.isEmpty || items.any((item) => !item.status.isTerminal)) {
        continue;
      }
      _terminalBatchesNotified.add(batch.id);
      await _showTerminalBatchNotification(
        id: _batchEventNotificationId(batch.id),
        batch: batch,
        items: items,
      );
    }
  }

  Future<void> _showTerminalEpisodeNotifications(
    DownloadManagerState state,
  ) async {
    final visibleIds = {for (final item in state.items) item.id};
    for (final id in _lastItemStatuses.keys.toList()) {
      if (!visibleIds.contains(id)) _lastItemStatuses.remove(id);
    }
    for (final item in state.items) {
      final previousStatus = _lastItemStatuses[item.id];
      _lastItemStatuses[item.id] = item.status;
      if (!item.status.isTerminal || previousStatus == item.status) continue;
      await _showTerminalEpisodeNotification(
        id: _episodeEventNotificationId(item.id),
        item: item,
        batch: _batchById(state, item.batchId),
      );
    }
  }

  Future<void> _showTerminalBatchNotification({
    required int id,
    required DownloadBatchQueue batch,
    required List<DownloadQueueItem> items,
  }) async {
    final failed = items
        .where((item) => item.status == DownloadQueueStatus.failed)
        .length;
    final cancelled = items
        .where((item) => item.status == DownloadQueueStatus.cancelled)
        .length;
    final completed = items
        .where((item) => item.status == DownloadQueueStatus.completed)
        .length;
    final status = failed > 0
        ? 'Batch finished with errors'
        : cancelled == items.length
        ? 'Batch cancelled'
        : 'Batch completed';
    final body = failed > 0 || cancelled > 0
        ? '$status · $completed completed · $failed failed · $cancelled cancelled'
        : status;
    await _notifications.show(
      id: id,
      title: batch.title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          AndroidForegroundDownloadRuntime._eventsChannelId,
          'Download updates',
          channelDescription: 'Senpwai download completion and error updates.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: 'ic_notification',
        ),
      ),
      payload: _payload(NotificationActionTargetType.batch, batch.id),
    );
  }

  Future<void> _showTerminalEpisodeNotification({
    required int id,
    required DownloadQueueItem item,
    required DownloadBatchQueue? batch,
  }) async {
    final body = _terminalEpisodeBody(item, batch);
    await _notifications.show(
      id: id,
      title: item.displayTitle,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          AndroidForegroundDownloadRuntime._eventsChannelId,
          'Download updates',
          channelDescription: 'Senpwai download completion and error updates.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: 'ic_notification',
        ),
      ),
      payload: _payload(NotificationActionTargetType.download, item.id),
    );
  }

  void _baselineTerminalState(DownloadManagerState state) {
    _lastItemStatuses
      ..clear()
      ..addEntries(state.items.map((item) => MapEntry(item.id, item.status)));
    _terminalBatchesNotified
      ..clear()
      ..addAll(
        state.batches
            .where((batch) {
              final items = _itemsForBatch(state, batch);
              return items.isNotEmpty &&
                  items.every((item) => item.status.isTerminal);
            })
            .map((batch) => batch.id),
      );
  }

  void _sendState(DownloadManagerState state) {
    FlutterForegroundTask.sendDataToMain({
      'kind': 'state',
      'state': DownloadRuntimeCodec.encodeState(state),
    });
  }

  void _sendResponse(String requestId, {Object? result, String? error}) {
    if (requestId.isEmpty) return;
    FlutterForegroundTask.sendDataToMain({
      'kind': 'response',
      'requestId': requestId,
      'result': result,
      'error': error,
    });
  }

  void _sendError({
    required String title,
    required String description,
    String? copyPayload,
  }) {
    FlutterForegroundTask.sendDataToMain({
      'kind': 'error',
      'title': title,
      'description': description,
      'copyPayload': copyPayload,
    });
  }

  Future<InProcessDownloadRuntime?> _waitForRuntime() async {
    final runtime = _runtime;
    if (runtime != null) return runtime;
    try {
      return await _runtimeReady.future.timeout(_runtimeReadyTimeout);
    } on TimeoutException {
      return null;
    }
  }
}

_AggregateProgress _aggregateProgress(List<DownloadQueueItem> items) {
  final totalBytes = items.fold<int>(0, (sum, item) => sum + item.totalBytes);
  final downloadedBytes = items.fold<int>(
    0,
    (sum, item) => sum + item.downloadedBytes,
  );
  final bytesPerSecond = items.fold<double>(
    0,
    (sum, item) => sum + item.bytesPerSecond,
  );
  final progress = totalBytes <= 0 ? 0.0 : downloadedBytes / totalBytes;
  return _AggregateProgress(
    percent: (progress * 100).round().clamp(0, 100),
    downloadedBytes: downloadedBytes,
    totalBytes: totalBytes,
    bytesPerSecond: bytesPerSecond,
  );
}

String _batchProgressBody(
  List<DownloadQueueItem> items,
  _AggregateProgress aggregate, {
  required _BatchNotificationStatus status,
}) {
  final downloaded = formatBytes(aggregate.downloadedBytes);
  final total = aggregate.totalBytes > 0
      ? formatBytes(aggregate.totalBytes)
      : 'Unknown';
  final prefix = status.label;
  final base =
      '$prefix · ${items.length} items · ${aggregate.percent}% · $downloaded / $total';
  if (status != _BatchNotificationStatus.downloading) return base;
  final speed = aggregate.bytesPerSecond <= 0
      ? 'Starting...'
      : '${formatBytes(aggregate.bytesPerSecond.round())}/s';
  return '$base · $speed';
}

String _terminalEpisodeBody(DownloadQueueItem item, DownloadBatchQueue? batch) {
  final status = switch (item.status) {
    DownloadQueueStatus.completed => 'Download completed',
    DownloadQueueStatus.failed => item.errorTitle ?? 'Download failed',
    DownloadQueueStatus.cancelled => 'Download cancelled',
    DownloadQueueStatus.seeding => 'Seeding',
    _ => 'Download updated',
  };
  final parts = [
    status,
    if (batch != null) batch.title,
    if (item.status == DownloadQueueStatus.failed &&
        item.errorDescription != null)
      item.errorDescription!,
  ];
  return parts.join(' · ');
}

_BatchNotificationStatus _batchNotificationStatus(
  List<DownloadQueueItem> batchItems,
  List<DownloadQueueItem> activeItems,
) {
  if (activeItems.isEmpty) return _terminalBatchStatus(batchItems);
  if (activeItems.any(
    (item) =>
        item.status == DownloadQueueStatus.downloading ||
        item.status == DownloadQueueStatus.seeding,
  )) {
    return _BatchNotificationStatus.downloading;
  }
  if (activeItems.any((item) => item.status == DownloadQueueStatus.preparing)) {
    return _BatchNotificationStatus.preparing;
  }
  if (activeItems.any((item) => item.status == DownloadQueueStatus.paused)) {
    return _BatchNotificationStatus.paused;
  }
  return _BatchNotificationStatus.queued;
}

_BatchNotificationStatus _terminalBatchStatus(List<DownloadQueueItem> items) {
  if (items.any((item) => item.status == DownloadQueueStatus.failed)) {
    return _BatchNotificationStatus.failed;
  }
  if (items.every((item) => item.status == DownloadQueueStatus.cancelled)) {
    return _BatchNotificationStatus.cancelled;
  }
  if (items.every((item) => item.status == DownloadQueueStatus.completed)) {
    return _BatchNotificationStatus.completed;
  }
  return _BatchNotificationStatus.finished;
}

NotificationProgress _notificationProgress(
  _AggregateProgress aggregate,
  _BatchNotificationStatus status,
) {
  if (status.isTerminal) return const NotificationProgress.none();
  if (status == _BatchNotificationStatus.preparing ||
      status == _BatchNotificationStatus.cancelling ||
      aggregate.totalBytes <= 0) {
    return const NotificationProgress(max: 0, progress: 0, indeterminate: true);
  }
  return NotificationProgress(max: 100, progress: aggregate.percent);
}

DownloadBatchQueue? _batchById(DownloadManagerState state, String id) {
  for (final batch in state.batches) {
    if (batch.id == id) return batch;
  }
  return null;
}

List<DownloadQueueItem> _itemsForBatch(
  DownloadManagerState state,
  DownloadBatchQueue batch,
) {
  final byId = {for (final item in state.items) item.id: item};
  return [
    for (final id in batch.itemIds)
      if (byId[id] != null) byId[id]!,
  ];
}

bool _activeBatchIsTerminal(DownloadManagerState state) {
  final activeBatchId = state.activeBatchId;
  if (activeBatchId == null) return false;
  final activeBatch = _batchById(state, activeBatchId);
  if (activeBatch == null) return false;
  final items = _itemsForBatch(state, activeBatch);
  return items.isNotEmpty && items.every((item) => item.status.isTerminal);
}

Map<String, dynamic> _foregroundStateMetadata(DownloadManagerState state) {
  final terminalItems = state.items
      .where((item) => item.status.isTerminal)
      .length;
  return {
    'activeBatchId': state.activeBatchId,
    'batchCount': state.batches.length,
    'itemCount': state.items.length,
    'terminalItemCount': terminalItems,
    'nonTerminalItemCount': state.items.length - terminalItems,
  };
}

List<NotificationButton> _notificationButtonsForStatus(
  _BatchNotificationStatus status,
) {
  if (status.isTerminal) return const [];
  return [
    NotificationButton(
      id: status == _BatchNotificationStatus.paused
          ? AndroidForegroundDownloadRuntime._actionResume
          : AndroidForegroundDownloadRuntime._actionPause,
      text: status == _BatchNotificationStatus.paused ? 'Resume' : 'Pause',
    ),
    const NotificationButton(
      id: AndroidForegroundDownloadRuntime._actionCancel,
      text: 'Cancel',
    ),
  ];
}

Map<String, Object?> _encodeNotificationSettings(
  NotificationPreferences settings,
) {
  return {
    'enabled': settings.enabled,
    'permissionDenied': settings.permissionDenied,
    'downloadStyle': settings.downloadStyle.name,
  };
}

NotificationPreferences _decodeNotificationSettings(Map<Object?, Object?> map) {
  final styleName = _string(map['downloadStyle']);
  return NotificationPreferences(
    enabled: map['enabled'] is bool ? map['enabled'] as bool : true,
    permissionDenied: map['permissionDenied'] is bool
        ? map['permissionDenied'] as bool
        : false,
    downloadStyle: _downloadNotificationStyleValue(styleName),
  );
}

DownloadNotificationStyle _downloadNotificationStyleValue(String value) {
  return switch (value) {
    'episodeCompletion' ||
    'eachDownload' => DownloadNotificationStyle.episodeCompletion,
    'batchCompletion' ||
    'batchSummary' ||
    'completionOnly' => DownloadNotificationStyle.batchCompletion,
    _ => DownloadNotificationStyle.batchCompletion,
  };
}

String _payload(NotificationActionTargetType type, String id) {
  final prefix = switch (type) {
    NotificationActionTargetType.download => 'download',
    NotificationActionTargetType.batch => 'batch',
  };
  return '$prefix:$id';
}

int _batchEventNotificationId(String batchId) =>
    _stableNotificationId('batch-event:$batchId');

int _episodeEventNotificationId(String itemId) =>
    _stableNotificationId('episode-event:$itemId');

int _stableNotificationId(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

Map<Object?, Object?> _map(Object? value) {
  if (value is! Map) return const {};
  return {for (final entry in value.entries) entry.key: entry.value};
}

Map<String, Object?> _mapString(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

String _string(Object? value) => value is String ? value : '';

String? _stringOrNull(Object? value) => value is String ? value : null;

int _int(Object? value) => value is int ? value : 0;

class _AggregateProgress {
  final int percent;
  final int downloadedBytes;
  final int totalBytes;
  final double bytesPerSecond;

  const _AggregateProgress({
    required this.percent,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.bytesPerSecond,
  });
}

enum _BatchNotificationStatus {
  preparing('Preparing', false),
  queued('Queued', false),
  downloading('Downloading', false),
  pausing('Pausing', false),
  paused('Paused', false),
  resuming('Resuming', false),
  cancelling('Cancelling', false),
  completed('Completed', true),
  failed('Finished with errors', true),
  cancelled('Cancelled', true),
  finished('Finished', true);

  final String label;
  final bool isTerminal;

  const _BatchNotificationStatus(this.label, this.isTerminal);
}
