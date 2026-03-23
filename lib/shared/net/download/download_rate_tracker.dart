import 'dart:async';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

final log = Logger("senpwai.shared.net.download.download_rate_tracker");

class DownloadRateTracker {
  static final _trackers = <DownloadRateTracker>{};
  final Stopwatch _updatesStopwatch = Stopwatch();
  final _updateController = StreamController<double>.broadcast();
  static final _globalUpdateController = StreamController<double>.broadcast();
  int _bytesDownloadedBuffer = 0;
  static const _minUpdateDuration = Duration(seconds: 1);
  Timer? _inactivityTimer;
  Timer? _ticker;

  double _bytesPerSecond = 0;
  double get bytesPerSecond => _bytesPerSecond;
  Stream<double> get updateStream => _updateController.stream;
  static Stream<double> get globalUpdateStream =>
      _globalUpdateController.stream;

  static double get globalBytesPerSecond =>
      _trackers.map((t) => t.bytesPerSecond).sum;

  DownloadRateTracker() {
    _trackers.add(this);
  }

  void _ensureTicker() {
    if (_ticker?.isActive ?? false) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void start() {
    _ensureTicker();
    _updatesStopwatch.start();
    _resetInactivityTimer();
  }

  void pause() {
    resetBytesState();
    _updatesStopwatch.stop();
    _inactivityTimer?.cancel();
    _ticker?.cancel();
  }

  void resume() {
    _ensureTicker();
    _updatesStopwatch.start();
    _resetInactivityTimer();
  }

  void dispose() {
    _updatesStopwatch.stop();
    _inactivityTimer?.cancel();
    _ticker?.cancel();
    _updateController.close();
    _trackers.remove(this);
  }

  void _tick() {
    if (!_updatesStopwatch.isRunning) return;

    final elapsed = _updatesStopwatch.elapsedMilliseconds;
    // Force a recalculation every second even if 0 bytes came in
    if (elapsed >= _minUpdateDuration.inMilliseconds) {
      _bytesPerSecond = _bytesDownloadedBuffer / (elapsed / 1000.0);

      _updatesStopwatch.reset();
      _bytesDownloadedBuffer = 0;

      _updateController.add(_bytesPerSecond);
      _globalUpdateController.add(globalBytesPerSecond);
    }
  }

  void update(int bytesDownloaded) {
    _resetInactivityTimer();

    _bytesDownloadedBuffer += bytesDownloaded;
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
