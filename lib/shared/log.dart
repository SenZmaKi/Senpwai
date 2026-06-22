import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

extension LoggerExtensions on Logger {
  void severeWithMetadata(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    final msg =
        "$message (error: $error, stacktrace: $stackTrace, metadata: $metadata)";
    severe(msg);
  }

  void fineWithMetadata(Object? message, {Map<String, dynamic>? metadata}) {
    final msg = "$message (metadata: $metadata)";
    fine(msg);
  }

  void infoWithMetadata(Object? message, {Map<String, dynamic>? metadata}) {
    final msg = "$message (metadata: $metadata)";
    info(msg);
  }

  void warningWithMetadata(Object? message, {Map<String, dynamic>? metadata}) {
    final msg = "$message (metadata: $metadata)";
    warning(msg);
  }
}

String _getColorForLevel(Level level) => switch (level) {
  Level.SEVERE => '❌ \x1B[31m', // Red
  Level.WARNING => '⚠️ \x1B[33m', // Yellow
  Level.FINE => '✅ \x1B[32m', // Green
  _ => '\x1B[37m', // White (default)
};

String? _debugLogPath;

void _writeDebugLog(String line) {
  if (!kDebugMode) return;
  final path = _debugLogPath;
  if (path == null) return;
  try {
    File(path).writeAsStringSync('$line\n', mode: FileMode.append);
  } catch (_) {
    // Logging must never break app startup or network requests.
  }
}

void setupLogger() {
  Logger.root.level = Level.ALL;
  if (kDebugMode) {
    _debugLogPath = '${Directory.systemTemp.path}/senpwai-debug.log';
    try {
      File(_debugLogPath!).writeAsStringSync('');
      debugPrint('Debug log file: $_debugLogPath');
    } catch (_) {
      _debugLogPath = null;
    }
  }
  Logger.root.onRecord.listen((record) {
    final color = _getColorForLevel(record.level);
    const reset = '\x1B[0m';
    final loggerName = '[${record.loggerName}]';
    final timestamp = record.time.toIso8601String();

    final lines = record.message.toString().split('\n');
    for (final line in lines) {
      // TODO: Flutter's logger shouldn't be used by backend code.
      debugPrint('$color${record.level.name} $loggerName: $line$reset');
      _writeDebugLog('$timestamp ${record.level.name} $loggerName: $line');
    }
  });
}
