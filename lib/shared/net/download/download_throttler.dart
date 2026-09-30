import 'dart:async';
import 'dart:typed_data';
import 'package:senpwai/shared/net/download/download_config.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

final log = Logger("senpwai.shared.net.download.download_throttler");

class DownloadThrottler {
  static DownloadThrottler? _instance;

  static DownloadThrottler getInstance() => _instance ??= DownloadThrottler();

  late double _availableBytes;
  late DateTime _lastConsumeTime;

  DownloadThrottler() {
    _availableBytes = DownloadConfig.getInstance().maxBytesPerSecond;
    _lastConsumeTime = DateTime.now();
  }

  Future<void> _consumeBytes(int requiredBytes) async {
    while (true) {
      final maxBytesPerSecond = DownloadConfig.getInstance().maxBytesPerSecond;
      if (maxBytesPerSecond <= 0) return;

      final now = DateTime.now();
      final secondsSinceLastConsume =
          now.difference(_lastConsumeTime).inMicroseconds /
          Duration.microsecondsPerSecond;

      _lastConsumeTime = now;

      final earnedBytes = (secondsSinceLastConsume * maxBytesPerSecond);
      final burstSizeBytes = maxBytesPerSecond * 2;
      _availableBytes = (earnedBytes + _availableBytes).clamp(
        0.0,
        burstSizeBytes,
      );
      if (_availableBytes >= requiredBytes) {
        _availableBytes -= requiredBytes;
        return;
      }
      final neededBytes = requiredBytes - _availableBytes;
      final microssecondsToWait =
          (neededBytes / maxBytesPerSecond * Duration.microsecondsPerSecond)
              .round();
      await Future.delayed(Duration(microseconds: microssecondsToWait));
    }
  }

  Stream<Uint8List> getThrottledStream(Response<ResponseBody> response) =>
      response.data!.stream.asyncExpand((data) async* {
        await _consumeBytes(data.length);
        yield data;
      });
}
