import 'dart:async';
import 'dart:collection';

const maxParallelSourceRequests = 10;
const maxParallelKwikRequests = 2;

class SourceConcurrencyLimits {
  SourceConcurrencyLimits._();

  static final instance = SourceConcurrencyLimits._();

  int animeHeaven = 5;
  int animePahe = maxParallelSourceRequests;
  int kwik = maxParallelKwikRequests;
  int nyaa = 5;
  int tokyoInsider = maxParallelSourceRequests;

  void update({
    required int animeHeaven,
    required int animePahe,
    required int kwik,
    required int nyaa,
    required int tokyoInsider,
  }) {
    this.animeHeaven = animeHeaven;
    this.animePahe = animePahe;
    this.kwik = kwik;
    this.nyaa = nyaa;
    this.tokyoInsider = tokyoInsider;
  }
}

class AsyncLimiter {
  final int maxConcurrent;
  final Queue<Completer<void>> _waiters = Queue();
  var _active = 0;

  AsyncLimiter(this.maxConcurrent) {
    if (maxConcurrent < 1) {
      throw ArgumentError.value(
        maxConcurrent,
        'maxConcurrent',
        'Must be positive.',
      );
    }
  }

  Future<T> run<T>(Future<T> Function() operation) async {
    await _acquire();
    try {
      return await operation();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_active < maxConcurrent) {
      _active++;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    return waiter.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
      return;
    }
    _active--;
  }
}

/// Runs [operation] with at most [maxConcurrent] items in flight while
/// preserving the input order in the returned list.
Future<List<R>> parallelMapOrdered<T, R>(
  Iterable<T> values, {
  required int maxConcurrent,
  required Future<R> Function(T value) operation,
}) async {
  if (maxConcurrent < 1) {
    throw ArgumentError.value(
      maxConcurrent,
      'maxConcurrent',
      'Must be positive.',
    );
  }

  final items = values.toList(growable: false);
  if (items.isEmpty) return <R>[];

  final results = List<Object?>.filled(items.length, null);
  var nextIndex = 0;
  var stopped = false;

  Future<void> worker() async {
    while (!stopped) {
      final index = nextIndex++;
      if (index >= items.length) return;
      try {
        results[index] = await operation(items[index]);
      } catch (_) {
        stopped = true;
        rethrow;
      }
    }
  }

  await Future.wait(
    List.generate(
      items.length < maxConcurrent ? items.length : maxConcurrent,
      (_) => worker(),
    ),
  );
  return List<R>.generate(items.length, (index) => results[index] as R);
}
