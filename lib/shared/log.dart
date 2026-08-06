import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

extension LoggerExtensions on Logger {
  void severeWithMetadata(
    Object? message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    if (!isLoggable(Level.SEVERE)) return;
    final msg =
        "$message (error: $error, stacktrace: $stackTrace, metadata: $metadata)";
    severe(msg);
  }

  void fineWithMetadata(Object? message, {Map<String, dynamic>? metadata}) {
    if (!isLoggable(Level.FINE)) return;
    final msg = "$message (metadata: $metadata)";
    fine(msg);
  }

  void infoWithMetadata(Object? message, {Map<String, dynamic>? metadata}) {
    if (!isLoggable(Level.INFO)) return;
    final msg = "$message (metadata: $metadata)";
    info(msg);
  }

  void warningWithMetadata(Object? message, {Map<String, dynamic>? metadata}) {
    if (!isLoggable(Level.WARNING)) return;
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

const _maxLogWriteBatchBytes = 64 * 1024;

_AsyncLogWriter? _logWriter;
var _isLoggerConfigured = false;

/// Writes app logs to [logsDirectory]/senpwai.log, retaining at most 25 MiB.
///
/// The log is truncated before an append that would exceed the cap. Logging is
/// deliberately best-effort so storage failures cannot affect app behaviour.
Future<void> configureFileLogging(Directory logsDirectory) async {
  try {
    await _logWriter?.flush();
    await logsDirectory.create(recursive: true);
    final file = File('${logsDirectory.path}/$_logFileName');
    final exists = await file.exists();
    var fileSize = exists ? await file.length() : 0;
    if (fileSize > maxLogFileBytes) {
      await file.writeAsBytes(const [], mode: FileMode.write);
      fileSize = 0;
    }
    _logWriter = _AsyncLogWriter(file: file, initialSize: fileSize);
    if (kDebugMode) debugPrint('Log file: ${file.path}');
  } catch (_) {
    _logWriter = null;
  }
}

void _writeLog(String line) {
  _logWriter?.add(line);
}

class _AsyncLogWriter {
  final File file;
  final Queue<Uint8List> _pending = Queue<Uint8List>();

  int _fileSize;
  bool _isDraining = false;
  bool _disabled = false;
  Completer<void>? _idleCompleter;

  _AsyncLogWriter({required this.file, required int initialSize})
    : _fileSize = initialSize;

  void add(String line) {
    if (_disabled) return;
    final bytes = utf8.encode('$line\n');
    if (bytes.length > maxLogFileBytes) return;
    _pending.add(Uint8List.fromList(bytes));
    _idleCompleter ??= Completer<void>();
    if (_isDraining) return;
    _isDraining = true;
    unawaited(Future<void>.microtask(_drain));
  }

  Future<void> flush() async {
    while (_isDraining || _pending.isNotEmpty) {
      final idle = _idleCompleter;
      if (idle == null) return;
      await idle.future;
    }
  }

  Future<void> _drain() async {
    try {
      while (_pending.isNotEmpty) {
        final batch = BytesBuilder(copy: false);
        var batchLength = 0;
        while (_pending.isNotEmpty) {
          final next = _pending.first;
          if (batchLength > 0 &&
              batchLength + next.length > _maxLogWriteBatchBytes) {
            break;
          }
          _pending.removeFirst();
          batch.add(next);
          batchLength += next.length;
        }

        if (_fileSize + batchLength > maxLogFileBytes) {
          await file.writeAsBytes(const [], mode: FileMode.write);
          _fileSize = 0;
        }
        await file.writeAsBytes(batch.takeBytes(), mode: FileMode.append);
        _fileSize += batchLength;
      }
    } catch (_) {
      // Logging must never break app startup or network requests. Disable a
      // failed writer so a burst of logs cannot repeatedly hit a bad path.
      _pending.clear();
      _disabled = true;
    } finally {
      _isDraining = false;
      final idle = _idleCompleter;
      _idleCompleter = null;
      if (idle != null && !idle.isCompleted) idle.complete();
      if (_pending.isNotEmpty && !_disabled) {
        _isDraining = true;
        _idleCompleter = Completer<void>();
        unawaited(Future<void>.microtask(_drain));
      }
    }
  }
}

void setupLogger() {
  if (_isLoggerConfigured) return;
  _isLoggerConfigured = true;
  // Fine-grained call-by-call traces are better represented by DevTools
  // timeline spans. Keep production logs focused on actionable failures.
  Logger.root.level = kDebugMode ? Level.INFO : Level.WARNING;
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
