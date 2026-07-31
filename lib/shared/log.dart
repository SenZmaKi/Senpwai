import 'dart:convert';
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

const maxLogFileBytes = 25 * 1024 * 1024;
const _logFileName = 'senpwai.log';

File? _logFile;
var _logFileSize = 0;
var _isLoggerConfigured = false;

/// Writes app logs to [logsDirectory]/senpwai.log, retaining at most 25 MiB.
///
/// The log is truncated before an append that would exceed the cap. Logging is
/// deliberately best-effort so storage failures cannot affect app behaviour.
void configureFileLogging(Directory logsDirectory) {
  try {
    logsDirectory.createSync(recursive: true);
    final file = File('${logsDirectory.path}/$_logFileName');
    if (file.existsSync() && file.lengthSync() > maxLogFileBytes) {
      file.writeAsStringSync('');
    }
    _logFile = file;
    _logFileSize = file.existsSync() ? file.lengthSync() : 0;
    if (kDebugMode) debugPrint('Log file: ${file.path}');
  } catch (_) {
    _logFile = null;
    _logFileSize = 0;
  }
}

void _writeLog(String line) {
  final file = _logFile;
  if (file == null) return;
  try {
    final entry = '$line\n';
    final entryLength = utf8.encode(entry).length;
    if (_logFileSize + entryLength > maxLogFileBytes) {
      file.writeAsStringSync('');
      _logFileSize = 0;
    }
    if (entryLength > maxLogFileBytes) return;
    file.writeAsStringSync(entry, mode: FileMode.append);
    _logFileSize += entryLength;
  } catch (_) {
    // Logging must never break app startup or network requests.
  }
}

void setupLogger() {
  if (_isLoggerConfigured) return;
  _isLoggerConfigured = true;
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final color = _getColorForLevel(record.level);
    const reset = '\x1B[0m';
    final loggerName = '[${record.loggerName}]';
    final timestamp = record.time.toIso8601String();

    final lines = record.message.toString().split('\n');
    for (final line in lines) {
      // TODO: Flutter's logger shouldn't be used by backend code.
      debugPrint('$color${record.level.name} $loggerName: $line$reset');
      _writeLog('$timestamp ${record.level.name} $loggerName: $line');
    }
  });
}
