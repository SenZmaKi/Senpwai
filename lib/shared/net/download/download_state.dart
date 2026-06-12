import 'dart:async';
import 'package:dio/dio.dart';
import 'package:senpwai/shared/net/download/download_rate_tracker.dart';
import 'package:senpwai/shared/net/download/shared.dart';
import 'package:senpwai/shared/log.dart';
import 'package:logging/logging.dart';

final log = Logger("senpwai.shared.net.download.download_state");

enum DownloadStatus { idle, downloading, paused, cancelled, completed, failed }

extension DownloadStatusExtension on DownloadStatus {
  static List<DownloadStatus> get terminalStatuses => [
    DownloadStatus.completed,
    DownloadStatus.cancelled,
    DownloadStatus.failed,
  ];
  bool get isTerminal => terminalStatuses.contains(this);
}

class DownloadState {
  final DownloadParams params;
  final _subscriptions = <int, StreamSubscription<List<int>>>{};
  final _partCompleters = <int, Completer<void>>{};
  final _iterationTokens = <int, CancelToken>{};
  final _pauseCancellableIterationTokens = <int>{};

  static const String pauseCancelReason = '__senpwai_pause__';
  static const String cancelReason = '__senpwai_cancel__';
  final _progressController = StreamController<DownloadProgress>.broadcast();
  final _statusController = StreamController<DownloadStatus>.broadcast();
  static final _globalStatusController =
      StreamController<DownloadStatus>.broadcast();

  Stream<DownloadStatus> get statusStream => _statusController.stream;
  static Stream<DownloadStatus> get globalStatusStream =>
      _globalStatusController.stream;

  final rateTracker = DownloadRateTracker();

  DownloadStatus _status = DownloadStatus.idle;

  DownloadStatus get status => _status;

  DownloadState({required this.params});

  Stream<DownloadProgress> get progressStream => _progressController.stream;
  bool get isStarted => status != DownloadStatus.idle;
  bool get isPaused => status == DownloadStatus.paused;
  bool get isCancelled => status == DownloadStatus.cancelled;
  bool get isComplete => status == DownloadStatus.completed;
  bool get isTerminal => status.isTerminal;
  @override
  String toString() => "DownloadState(params: $params, status: $status)";

  void addProgress(DownloadProgress prog) {
    if (!_progressController.isClosed) _progressController.add(prog);
    rateTracker.update(prog.bytesDownloaded);
  }

  void startRateTracking() {
    rateTracker.start();
  }

  void _stopRateTracking() {
    rateTracker.dispose();
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

  CancelToken registerIterationToken(
    int partNumber, {
    bool cancelOnPause = true,
  }) {
    final token = CancelToken();
    _iterationTokens[partNumber] = token;
    if (cancelOnPause) {
      _pauseCancellableIterationTokens.add(partNumber);
    }
    if (isPaused && cancelOnPause) {
      token.cancel(pauseCancelReason);
    } else if (isCancelled) {
      token.cancel(cancelReason);
    }
    return token;
  }

  void unregisterIterationToken(int partNumber) {
    _iterationTokens.remove(partNumber);
    _pauseCancellableIterationTokens.remove(partNumber);
  }

  void finalize(DownloadStatus status) {
    if (isTerminal) return;
    _stopRateTracking();
    if (!_progressController.isClosed) _progressController.close();
    _updateStatus(status);
    if (!_statusController.isClosed) _statusController.close();
  }

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
    // Update status BEFORE cancelling so the iteration loop sees `isPaused`
    // when it catches the DioException and waits for resume instead of failing.
    _updateStatus(DownloadStatus.paused);
    for (final partNumber in _pauseCancellableIterationTokens) {
      final token = _iterationTokens[partNumber];
      if (token == null) continue;
      if (!token.isCancelled) token.cancel(pauseCancelReason);
    }
  }

  void resume() {
    if (status != DownloadStatus.paused) {
      log.fine("resume() noop: status=$status");
      return;
    }
    log.infoWithMetadata("Resuming download", metadata: {"params": params});
    rateTracker.resume();
    _updateStatus(DownloadStatus.downloading);
  }

  Future<DownloadStatus> waitTillStatus({List<DownloadStatus>? statuses}) {
    if (statuses == null || statuses.isEmpty) {
      return statusStream.first;
    }
    return statusStream.firstWhere((status) => statuses.contains(status));
  }

  Future<void> cancel() async {
    if (isTerminal || status == DownloadStatus.idle) {
      log.fine("cancel() noop: status=$status");
      return;
    }
    log.infoWithMetadata("Cancelling download", metadata: {"params": params});
    for (final token in _iterationTokens.values) {
      if (!token.isCancelled) token.cancel(cancelReason);
    }
    _iterationTokens.clear();
    _pauseCancellableIterationTokens.clear();

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
