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

void setupLogger() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final color = _getColorForLevel(record.level);
    const reset = '\x1B[0m';
    final loggerName = '[${record.loggerName}]';

    final lines = record.message.toString().split('\n');
    for (final line in lines) {
      // TODO: Flutter's logger shouldn't be used by backend code.
      debugPrint('$color${record.level.name} $loggerName: $line$reset');
    }
  });
}
