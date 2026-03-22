import 'dart:async';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:senpwai/shared/net/download/shared.dart';
import 'package:senpwai/shared/log.dart';
import 'package:logging/logging.dart';

final log = Logger("senpwai.shared.net.download.download_state");

enum DownloadStatus { idle, downloading, paused, cancelled, completed, failed }

class RateTracker {
  static final _trackers = <RateTracker>{};
  final Stopwatch _updatesStopwatch = Stopwatch();
  final _updateController = StreamController<double>.broadcast();
  static final _globalUpdateController = StreamController<double>.broadcast();
  int _bytesDownloadedBuffer = 0;
  static const _minUpdateDuration = Duration(seconds: 1);
  Timer? _inactivityTimer;

  double _bytesPerSecond = 0;
  double get bytesPerSecond => _bytesPerSecond;
  Stream<double> get updateStream => _updateController.stream;
  static Stream<double> get globalUpdateStream =>
      _globalUpdateController.stream;

  static double get globalBytesPerSecond =>
      _trackers.map((t) => t.bytesPerSecond).sum;

  RateTracker() {
    _trackers.add(this);
  }

  void start() {
    _updatesStopwatch.start();
    _resetInactivityTimer();
  }

  void pause() {
    resetBytesState();
    _updatesStopwatch.stop();
    _inactivityTimer?.cancel();
  }

  void resume() {
    _updatesStopwatch.start();
    _resetInactivityTimer();
  }

  void dispose() {
    _updatesStopwatch.stop();
    _inactivityTimer?.cancel();
    _updateController.close();
    _trackers.remove(this);
  }

  void update(int bytesDownloaded) {
    _resetInactivityTimer();

    _bytesDownloadedBuffer += bytesDownloaded;
    final elapsedMs = _updatesStopwatch.elapsedMilliseconds;

    if (bytesDownloaded == 0 || elapsedMs < _minUpdateDuration.inMilliseconds) {
      return;
    }

    _bytesPerSecond = _bytesDownloadedBuffer / (elapsedMs / 1000);

    _updatesStopwatch.reset();
    _bytesDownloadedBuffer = 0;
    _updateController.add(bytesPerSecond);
    _globalUpdateController.add(globalBytesPerSecond);
  }

  void resetBytesState() {
    _bytesPerSecond = 0;
    _bytesDownloadedBuffer = 0;
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 10), resetBytesState);
  }
}

class DownloadState {
  final DownloadParams params;
  final CancelToken _cancelToken = CancelToken();
  final _subscriptions = <int, StreamSubscription<List<int>>>{};
  final _partCompleters = <int, Completer<void>>{};
  final _progressController = StreamController<DownloadProgress>.broadcast();
  final _statusController = StreamController<DownloadStatus>.broadcast();
  static final _globalStatusController =
      StreamController<DownloadStatus>.broadcast();

  Stream<DownloadStatus> get statusStream => _statusController.stream;
  static Stream<DownloadStatus> get globalStatusStream =>
      _globalStatusController.stream;

  final rateTracker = RateTracker();

  DownloadStatus _status = DownloadStatus.idle;

  DownloadStatus get status => _status;

  DownloadState({required this.params});

  Stream<DownloadProgress> get progressStream => _progressController.stream;
  CancelToken get cancelToken => _cancelToken;
  bool get isStarted => status != DownloadStatus.idle;
  bool get isPaused => status == DownloadStatus.paused;
  bool get isCancelled => status == DownloadStatus.cancelled;
  bool get isComplete => status == DownloadStatus.completed;
  bool get isTerminal => [
    DownloadStatus.completed,
    DownloadStatus.cancelled,
    DownloadStatus.failed,
  ].contains(status);

  @override
  String toString() => "DownloadState(params: $params, status: $status)";

  void addProgress(DownloadProgress prog) {
    if (!_progressController.isClosed) _progressController.add(prog);
  }

  void startRateTracking() {
    rateTracker.start();
  }

  void _stopRateTracking() {
    rateTracker.dispose();
  }

  void updateRate(int bytesDownloaded) {
    if (isTerminal || status == DownloadStatus.paused) return;
    rateTracker.update(bytesDownloaded);
  }

  void registerPart(
    int partNumber,
    StreamSubscription<List<int>> sub,
    Completer<void> completer,
  ) {
    _subscriptions[partNumber] = sub;
    _partCompleters[partNumber] = completer;
  }

  void unregisterPart(int partNumber) {
    _subscriptions.remove(partNumber);
    _partCompleters.remove(partNumber);
  }

  void finalize(DownloadStatus status) {
    if (isTerminal) return;
    _stopRateTracking();
    if (!_progressController.isClosed) _progressController.close();
    _updateStatus(status);
    if (!_statusController.isClosed) _statusController.close();
  }

  Future<void> waitTillFinished() => _progressController.stream.drain();

  void _updateStatus(DownloadStatus newStatus) {
    _status = newStatus;
    _statusController.add(status);
    _globalStatusController.add(status);
  }

  void updateToDownloading() => _updateStatus(DownloadStatus.downloading);

  void pause() {
    if (status != DownloadStatus.downloading) {
      log.fine("pause() noop: status=$status");
      return;
    }
    log.infoWithMetadata("Pausing download", metadata: {"params": params});
    rateTracker.pause();
    for (final sub in _subscriptions.values) {
      sub.pause();
    }
    _updateStatus(DownloadStatus.paused);
  }

  void resume() {
    if (status != DownloadStatus.paused) {
      log.fine("resume() noop: status=$status");
      return;
    }
    log.infoWithMetadata("Resuming download", metadata: {"params": params});
    rateTracker.resume();
    for (final sub in _subscriptions.values) {
      sub.resume();
    }
    _updateStatus(DownloadStatus.downloading);
  }

  Future<void> cancel() async {
    if (isTerminal || status == DownloadStatus.idle) {
      log.fine("cancel() noop: status=$status");
      return;
    }
    log.infoWithMetadata("Cancelling download", metadata: {"params": params});
    _cancelToken.cancel("Cancelled by user");

    // Cancel all subscriptions
    final subs = List<StreamSubscription<List<int>>>.from(
      _subscriptions.values,
    );
    for (final sub in subs) {
      await sub.cancel();
    }
    _subscriptions.clear();

    // Complete all pending part completers with error so Future.wait unblocks
    final completers = List<Completer<void>>.from(_partCompleters.values);
    for (final completer in completers) {
      if (!completer.isCompleted) {
        completer.completeError(
          DownloadCancelledException("Download cancelled"),
        );
      }
    }
    _partCompleters.clear();

    finalize(DownloadStatus.cancelled);
  }
}
