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
const maxDiagnosticLogRecords = 200;
const maxDiagnosticLogBytes = 128 * 1024;
final Queue<({String text, int bytes})> _recentDiagnosticLogs = Queue();
int _recentDiagnosticLogBytes = 0;
final Queue<String> _earlyErrorReports = Queue<String>();
void Function(String)? _forwardDiagnosticLog;
String? _logFilePath;
String? _fileLoggingFailure;

String get diskLoggingStatus {
  final failure = _fileLoggingFailure;
  if (failure != null) return 'Failed: $failure';
  final path = _logFilePath;
  return path == null ? 'Not configured' : 'Writing to $path';
}

/// Wait for queued writes before an orderly exit or background transition.
Future<void> flushAppLogs() async => _logWriter?.flush();

void _reportFileLoggingFailure(Object error) {
  final message = sanitizeDiagnosticText('$_logFilePath: $error');
  _fileLoggingFailure = message;
  recordDiagnosticLog(
    '${DateTime.now().toIso8601String()} WARNING: Disk logging failed: $message',
  );
  try {
    stderr.writeln('Disk logging failed: $message');
  } catch (_) {
    // The in-memory diagnostic remains available without a console.
  }
}

/// Captures Dart console output from this operation and its asynchronous work.
T runWithLogCapture<T>(T Function() operation) => runZoned(
  operation,
  zoneSpecification: ZoneSpecification(
    print: (self, parent, zone, line) {
      recordDiagnosticLog('${DateTime.now().toIso8601String()} PRINT: $line');
      parent.print(zone, line);
    },
  ),
);

/// Receives an already formatted worker record without writing it twice.
void receiveDiagnosticLog(String text) => _rememberLogRecord(text);

void recordDiagnosticLog(String text) {
  final sanitized = sanitizeDiagnosticText(text);
  final remembered = _rememberLogRecord(sanitized);
  _writeLog(sanitized);
  _forwardDiagnosticLog?.call(remembered);
}

String sanitizeDiagnosticText(String text) {
  return text
      .replaceAllMapped(RegExp(r'https?://[^\s<>"\x27]+'), (match) {
        final uri = Uri.tryParse(match[0]!);
        if (uri == null) return '[invalid URL]';
        return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}${uri.path}';
      })
      .replaceAll(
        RegExp(
          r'(authorization|cookie|set-cookie|password|access_token|refresh_token)\s*[:=]\s*[^\n]+',
          caseSensitive: false,
        ),
        '[sensitive field redacted]',
      );
}

String get recentDiagnosticLogs =>
    _recentDiagnosticLogs.map((record) => record.text).join('\n');

String _rememberLogRecord(String text) {
  var sanitized = sanitizeDiagnosticText(text);
  var bytes = utf8.encode(sanitized).length + 1;
  if (bytes > maxDiagnosticLogBytes) {
    sanitized = '[Log record omitted: exceeds 128 KiB; see full app log]';
    bytes = utf8.encode(sanitized).length + 1;
  }
  _recentDiagnosticLogs.add((text: sanitized, bytes: bytes));
  _recentDiagnosticLogBytes += bytes;
  while (_recentDiagnosticLogs.length > maxDiagnosticLogRecords ||
      _recentDiagnosticLogBytes > maxDiagnosticLogBytes) {
    _recentDiagnosticLogBytes -= _recentDiagnosticLogs.removeFirst().bytes;
  }
  return sanitized;
}

void recordErrorReport(String report, {bool remember = true}) {
  final sanitized = sanitizeDiagnosticText(report);
  if (remember) {
    final remembered = _rememberLogRecord(sanitized);
    _forwardDiagnosticLog?.call(remembered);
  }
  _writeLog(sanitized);
}

/// Writes logs to [fileName] in [logsDirectory], retaining at most 25 MiB.
///
/// Each isolate must use its own filename so append and rotation have one owner.
/// The log is truncated before an append that would exceed the cap. Logging is
/// deliberately best-effort so storage failures cannot affect app behaviour.
Future<void> configureFileLogging(
  Directory logsDirectory, {
  String fileName = _logFileName,
}) async {
  _logFilePath = '${logsDirectory.path}/$fileName';
  _fileLoggingFailure = null;
  try {
    await _logWriter?.flush();
    await logsDirectory.create(recursive: true);
    final file = File(_logFilePath!);
    final exists = await file.exists();
    var fileSize = exists ? await file.length() : 0;
    if (fileSize > maxLogFileBytes) {
      await file.writeAsBytes(const [], mode: FileMode.write);
      fileSize = 0;
    }
    _logWriter = _AsyncLogWriter(file: file, initialSize: fileSize);
    while (_earlyErrorReports.isNotEmpty) {
      _logWriter!.add(_earlyErrorReports.removeFirst());
    }
  } catch (error) {
    _logWriter = null;
    _reportFileLoggingFailure(error);
  }
}

void _writeLog(String line) {
  final writer = _logWriter;
  if (writer != null) {
    writer.add(line);
  } else {
    _earlyErrorReports.add(line);
    while (_earlyErrorReports.length > maxDiagnosticLogRecords ||
        _earlyErrorReports.fold<int>(
              0,
              (bytes, record) => bytes + utf8.encode(record).length + 1,
            ) >
            maxDiagnosticLogBytes) {
      _earlyErrorReports.removeFirst();
    }
  }
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
        await file.writeAsBytes(
          batch.takeBytes(),
          mode: FileMode.append,
          flush: true,
        );
        _fileSize += batchLength;
      }
    } catch (error) {
      // Logging must never break app startup or network requests. Disable a
      // failed writer so a burst of logs cannot repeatedly hit a bad path.
      _pending.clear();
      _disabled = true;
      _reportFileLoggingFailure(error);
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

void setupLogger({void Function(String)? forwardDiagnosticLog}) {
  _forwardDiagnosticLog = forwardDiagnosticLog;
  if (_isLoggerConfigured) return;
  _isLoggerConfigured = true;
  // Fine-grained call-by-call traces are better represented by DevTools
  // timeline spans. Keep production logs focused on actionable failures.
  Logger.root.level = Level.INFO;
  final consoleDebugPrint = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    if (message != null) {
      recordDiagnosticLog(
        '${DateTime.now().toIso8601String()} DEBUG: $message',
      );
    }
    // Console output must bypass the print capture to avoid duplicate records.
    Zone.root.run(() => consoleDebugPrint(message, wrapWidth: wrapWidth));
  };
  recordDiagnosticLog(
    '${DateTime.now().toIso8601String()} INFO: App log capture initialized',
  );
  Logger.root.onRecord.listen((record) {
    final color = _getColorForLevel(record.level);
    const reset = '\x1B[0m';
    final loggerName = '[${record.loggerName}]';
    final timestamp = record.time.toIso8601String();

    final message =
        '${record.message}'
        '${record.error == null ? '' : '\nError: ${record.error}'}'
        '${record.stackTrace == null ? '' : '\n${record.stackTrace}'}';
    recordDiagnosticLog(
      '$timestamp ${record.level.name} $loggerName: $message',
    );
    final lines = message.split('\n');
    for (final line in lines) {
      // TODO: Flutter's logger shouldn't be used by backend code.
      Zone.root.run(
        () => consoleDebugPrint(
          '$color${record.level.name} $loggerName: $line$reset',
        ),
      );
    }
  });
}
