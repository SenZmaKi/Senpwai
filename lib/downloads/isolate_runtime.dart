import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:senpwai/downloads/in_process_runtime.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/downloads/runtime_codec.dart';
import 'package:senpwai/settings/settings.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/persistence/app_paths.dart';
import 'package:senpwai/shared/performance_trace.dart';

typedef _CommandPayload = Map<String, Object?>;

class DownloadIsolateRuntime implements DownloadRuntime {
  final DownloadRuntimeErrorHandler onError;
  final String appDataRootPath;
  final _stateController = StreamController<DownloadManagerState>.broadcast();
  final _pendingRequests = <String, Completer<Object?>>{};

  int _maxDownloadBytesPerSecond;
  String _downloadUserAgent;
  TorrentPreferences _torrentSettings;
  var _stateSnapshot = const DownloadManagerState();
  var _requestCounter = 0;
  final _receivedStateRate = TimelineRateCounter(
    'downloads.main_isolate_state_rate',
  );

  Isolate? _isolate;
  SendPort? _commandPort;
  ReceivePort? _receivePort;
  Completer<void>? _ready;

  DownloadIsolateRuntime({
    required int initialMaxDownloadBytesPerSecond,
    required String downloadUserAgent,
    required TorrentPreferences initialTorrentSettings,
    required this.appDataRootPath,
    required this.onError,
  }) : _maxDownloadBytesPerSecond = initialMaxDownloadBytesPerSecond,
       _downloadUserAgent = downloadUserAgent,
       _torrentSettings = initialTorrentSettings {
    unawaited(_start().catchError((_) {}));
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
    unawaited(
      _sendVoidCommand('updateHttpDownloadSettings', {
        'maxBytesPerSecond': maxBytesPerSecond,
        'userAgent': userAgent,
      }),
    );
  }

  @override
  void updateTorrentSettings(TorrentPreferences settings) {
    _torrentSettings = settings;
    unawaited(
      _sendVoidCommand('updateTorrentSettings', {
        'settings': DownloadRuntimeCodec.encodeTorrentSettings(settings),
      }),
    );
  }

  @override
  void updateNotificationSettings(NotificationPreferences settings) {}

  @override
  Future<void> dispose() async {
    final port = _commandPort;
    if (port != null) {
      port.send(const {'kind': 'shutdown'});
    }
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Download isolate detached.'));
      }
    }
    _pendingRequests.clear();
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    await _stateController.close();
  }

  Future<void> _sendVoidCommand(String type, _CommandPayload payload) async {
    await _sendCommand(type, payload);
  }

  Future<Object?> _sendCommand(String type, _CommandPayload payload) async {
    await _ensureReady();
    final requestId = _nextRequestId();
    final completer = Completer<Object?>();
    _pendingRequests[requestId] = completer;
    _commandPort?.send({
      'kind': 'command',
      'requestId': requestId,
      'type': type,
      'payload': payload,
    });
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingRequests.remove(requestId);
        throw TimeoutException('Timed out waiting for download command $type.');
      },
    );
  }

  Future<void> _ensureReady() {
    final ready = _ready;
    return (ready?.future ?? _start()).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException(
        'Timed out while starting the download engine.',
      ),
    );
  }

  Future<void> _start() {
    final existing = _ready;
    if (existing != null) return existing.future;

    final ready = Completer<void>();
    _ready = ready;
    final receivePort = ReceivePort();
    _receivePort = receivePort;
    receivePort.listen(_onIsolateMessage);

    unawaited(_spawnIsolate(receivePort.sendPort, ready));
    return ready.future;
  }

  Future<void> _spawnIsolate(SendPort sendPort, Completer<void> ready) async {
    try {
      _isolate = await Isolate.spawn(_downloadIsolateEntry, {
        'sendPort': sendPort,
        'settings': DownloadRuntimeCodec.encodeTorrentSettings(
          _torrentSettings,
        ),
        'maxDownloadBytesPerSecond': _maxDownloadBytesPerSecond,
        'downloadUserAgent': _downloadUserAgent,
        'appDataRootPath': appDataRootPath,
      });
    } on Object catch (error, stackTrace) {
      if (!ready.isCompleted) ready.completeError(error, stackTrace);
      _handleIsolateFailure(error, stackTrace);
    }
  }

  void _onIsolateMessage(Object? data) {
    final message = _mapString(data);
    switch (_string(message['kind'])) {
      case 'ready':
        _commandPort = message['sendPort'] as SendPort?;
        final stateValue = message['state'];
        if (stateValue != null) {
          _publishState(DownloadRuntimeCodec.decodeState(_map(stateValue)));
        }
        final ready = _ready;
        if (ready != null && !ready.isCompleted) ready.complete();
      case 'state':
        final encodedState = _map(message['state']);
        final itemCount = _list(encodedState['items']).length;
        _receivedStateRate.record(
          units: itemCount,
          arguments: {'queueItems': itemCount},
        );
        _publishState(
          traceSync(
            'downloads.decode_state',
            () => DownloadRuntimeCodec.decodeState(encodedState),
            arguments: {'queueItems': itemCount},
          ),
        );
      case 'response':
        _onResponse(message);
      case 'error':
        onError(
          title: _string(message['title']),
          description: _string(message['description']),
          copyPayload: _stringOrNull(message['copyPayload']),
        );
      case 'fatal':
        _handleIsolateFailure(
          StateError(_string(message['error'])),
          StackTrace.fromString(_string(message['stackTrace'])),
        );
    }
  }

  void _publishState(DownloadManagerState next) {
    _stateSnapshot = next;
    if (!_stateController.isClosed) _stateController.add(next);
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

  void _handleIsolateFailure(Object error, StackTrace stackTrace) {
    // A failure before the isolate sends its ready message used to leave
    // [_ready] unresolved. Any preview submission then waited forever at
    // “Queueing downloads” in [_sendCommand]. Complete the startup handshake
    // as an error so the submission can show the actual engine failure.
    final ready = _ready;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(error, stackTrace);
    }
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
    _pendingRequests.clear();
    onError(
      title: 'Download engine failed',
      description: '$error',
      copyPayload: '$error\n\n$stackTrace',
    );
  }

  String _nextRequestId() {
    _requestCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_requestCounter';
  }
}

@pragma('vm:entry-point')
Future<void> _downloadIsolateEntry(Map<Object?, Object?> config) async {
  DartPluginRegistrant.ensureInitialized();
  setupLogger();
  final appDataRootPath = _string(config['appDataRootPath']);
  if (appDataRootPath.isEmpty) {
    throw StateError('Download isolate app data path is missing.');
  }
  // path_provider can remain pending when invoked from a background isolate
  // on macOS. The main isolate has already resolved this application path, so
  // use the explicit root and keep download-engine startup plugin-free.
  final paths = await AppPaths.fromRootDirectory(Directory(appDataRootPath));
  await configureFileLogging(paths.logsDirectory);

  final mainPort = config['sendPort'] as SendPort;
  final commandPort = ReceivePort();
  InProcessDownloadRuntime? runtime;
  StreamSubscription<DownloadManagerState>? stateSubscription;
  final sentStateRate = TimelineRateCounter('downloads.worker_state_rate');

  void sendState(DownloadManagerState state) {
    sentStateRate.record(
      units: state.items.length,
      arguments: {'queueItems': state.items.length},
    );
    mainPort.send({
      'kind': 'state',
      'state': traceSync(
        'downloads.encode_state',
        () => DownloadRuntimeCodec.encodeState(state),
        arguments: {'queueItems': state.items.length},
      ),
    });
  }

  void sendError({
    required String title,
    required String description,
    String? copyPayload,
  }) {
    mainPort.send({
      'kind': 'error',
      'title': title,
      'description': description,
      'copyPayload': copyPayload,
    });
  }

  try {
    final downloadUserAgent = _string(config['downloadUserAgent']);
    if (downloadUserAgent.isEmpty) {
      throw StateError('Download isolate user agent is missing.');
    }
    runtime = InProcessDownloadRuntime(
      downloadUserAgent: downloadUserAgent,
      initialMaxDownloadBytesPerSecond: _int(
        config['maxDownloadBytesPerSecond'],
      ),
      initialTorrentSettings: DownloadRuntimeCodec.decodeTorrentSettings(
        _map(config['settings']),
      ),
      onError: sendError,
    );
    stateSubscription = runtime.stateStream.listen(sendState);
    mainPort.send({
      'kind': 'ready',
      'sendPort': commandPort.sendPort,
      'state': DownloadRuntimeCodec.encodeState(runtime.currentState),
    });

    await for (final data in commandPort) {
      final message = _mapString(data);
      if (_string(message['kind']) == 'shutdown') break;
      if (_string(message['kind']) != 'command') continue;
      await _handleDownloadCommand(runtime, mainPort, message);
    }
  } on Object catch (error, stackTrace) {
    mainPort.send({
      'kind': 'fatal',
      'error': '$error',
      'stackTrace': '$stackTrace',
    });
  } finally {
    await stateSubscription?.cancel();
    await runtime?.dispose();
    commandPort.close();
  }
}

Future<void> _handleDownloadCommand(
  InProcessDownloadRuntime runtime,
  SendPort mainPort,
  Map<String, Object?> message,
) async {
  final requestId = _string(message['requestId']);
  final type = _string(message['type']);
  final payload = _map(message['payload']);
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
        result = null;
      case 'resume':
        await runtime.resume(_string(payload['id']));
        result = null;
      case 'cancel':
        await runtime.cancel(_string(payload['id']));
        result = null;
      case 'pauseBatch':
        await runtime.pauseBatch(_string(payload['batchId']));
        result = null;
      case 'resumeBatch':
        await runtime.resumeBatch(_string(payload['batchId']));
        result = null;
      case 'cancelBatch':
        await runtime.cancelBatch(_string(payload['batchId']));
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
          DownloadRuntimeCodec.decodeTorrentSettings(_map(payload['settings'])),
        );
        result = null;
      default:
        throw UnsupportedError('Unknown download command: $type');
    }
    mainPort.send({
      'kind': 'response',
      'requestId': requestId,
      'result': result,
    });
  } on Object catch (error, stackTrace) {
    mainPort.send({
      'kind': 'response',
      'requestId': requestId,
      'error':
          '$error\n\n${stackTrace.toString().split('\n').take(8).join('\n')}',
    });
  }
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

List<Object?> _list(Object? value) => value is List ? value : const [];
