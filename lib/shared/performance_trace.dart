import 'dart:developer';

/// Timeline wrappers that deliberately avoid the file-backed app logger.
Future<T> traceAsync<T>(
  String name,
  Future<T> Function() operation, {
  Map<String, Object?> arguments = const {},
}) async {
  final task = TimelineTask()..start(name, arguments: arguments);
  try {
    return await operation();
  } finally {
    task.finish();
  }
}

T traceSync<T>(
  String name,
  T Function() operation, {
  Map<String, Object?> arguments = const {},
}) => Timeline.timeSync(name, operation, arguments: arguments);

/// Emits an aggregate event periodically, avoiding one trace event per update.
class TimelineRateCounter {
  final String name;
  final Duration interval;

  final Stopwatch _stopwatch = Stopwatch()..start();
  int _events = 0;
  int _units = 0;

  TimelineRateCounter(this.name, {this.interval = const Duration(seconds: 1)});

  void record({int units = 0, Map<String, Object?> arguments = const {}}) {
    _events += 1;
    _units += units;
    if (_stopwatch.elapsed < interval) return;

    final elapsedSeconds =
        _stopwatch.elapsedMicroseconds / Duration.microsecondsPerSecond;
    Timeline.instantSync(
      name,
      arguments: {
        ...arguments,
        'events': _events,
        'eventsPerSecond': _events / elapsedSeconds,
        if (_units > 0) 'units': _units,
        if (_units > 0) 'unitsPerSecond': _units / elapsedSeconds,
      },
    );
    _events = 0;
    _units = 0;
    _stopwatch
      ..reset()
      ..start();
  }
}
