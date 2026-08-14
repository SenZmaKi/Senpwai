import 'dart:async';

import 'package:flutter/services.dart';

class MacOsUpdateBridge {
  static const _methods = MethodChannel('senpwai/sparkle_updater');
  static const _events = EventChannel('senpwai/sparkle_update_events');

  const MacOsUpdateBridge();

  Stream<Map<String, Object?>> get events => _events
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map((event) => Map<String, Object?>.from(event as Map));

  Future<void> start({required bool automaticallyDownload}) =>
      _methods.invokeMethod<void>('start', {
        'automaticallyDownload': automaticallyDownload,
      });

  Future<void> check() => _methods.invokeMethod<void>('check');

  Future<void> download() => _methods.invokeMethod<void>('download');

  Future<void> cancelDownload() =>
      _methods.invokeMethod<void>('cancelDownload');

  Future<void> installAndRestart() =>
      _methods.invokeMethod<void>('installAndRestart');

  Future<void> setAutomaticallyDownload(bool enabled) => _methods
      .invokeMethod<void>('setAutomaticallyDownload', {'enabled': enabled});
}
