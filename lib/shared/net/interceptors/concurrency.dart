import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';

/// Counting semaphore — limits how many operations run at the same time.
class _Semaphore {
  int _max;
  int _active = 0;
  final Queue<Completer<void>> _waiters = Queue();

  _Semaphore(this._max);

  void updateMax(int max) {
    _max = max;
    _drainWaiters();
  }

  Future<bool> acquire(Future<void>? cancelled) async {
    if (_active < _max) {
      _active++;
      return true;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    if (cancelled == null) {
      await completer.future;
      return true;
    }
    final acquired = await Future.any<bool>([
      completer.future.then((_) => true),
      cancelled.then((_) => false),
    ]);
    if (acquired) return true;
    if (_waiters.remove(completer)) return false;

    // The waiter was granted concurrently with cancellation. Return the slot
    // instead of leaking it into a request that will never be dispatched.
    release();
    return false;
  }

  void release() {
    if (_active > 0) {
      _active--;
    }
    _drainWaiters();
  }

  void _drainWaiters() {
    while (_active < _max && _waiters.isNotEmpty) {
      _active++;
      _waiters.removeFirst().complete();
    }
  }
}

class _SemaphoreLease {
  final _Semaphore semaphore;
  bool _released = false;

  _SemaphoreLease(this.semaphore);

  void release() {
    if (_released) return;
    _released = true;
    semaphore.release();
  }
}

/// Limits the number of concurrent in-flight HTTP requests **per host**.
///
/// The host limit is resolved per request, allowing a source directory update
/// to move a host without rebuilding the Dio client.
///
/// Example — cap nyaa.si at 5 concurrent requests:
/// ```dart
/// ConcurrencyInterceptor((host) => host == 'nyaa.si' ? 5 : null)
/// ```
class ConcurrencyInterceptor extends Interceptor {
  static const _semaphoreExtraKey = 'concurrency_semaphore';

  final Map<String, int> _hostLimits;
  final Map<String, _Semaphore> _semaphores = {};

  ConcurrencyInterceptor(Map<String, int> hostLimits)
    : _hostLimits = Map.of(hostLimits);

  void updateHostLimits(Map<String, int> hostLimits) {
    _semaphores.removeWhere((host, _) => !hostLimits.containsKey(host));
    for (final entry in hostLimits.entries) {
      _semaphores[entry.key]?.updateMax(entry.value);
    }
    _hostLimits
      ..clear()
      ..addAll(hostLimits);
  }

  _Semaphore? _semaphoreFor(String host) {
    final limit = _hostLimits[host];
    if (limit == null) return null;
    return _semaphores.putIfAbsent(host, () => _Semaphore(limit));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final semaphore = _semaphoreFor(options.uri.host);
    final cancelToken = options.cancelToken;
    if (cancelToken?.isCancelled ?? false) {
      handler.reject(cancelToken!.cancelError!);
      return;
    }
    final acquired =
        await semaphore?.acquire(cancelToken?.whenCancel.then<void>((_) {})) ??
        true;
    if (!acquired || (cancelToken?.isCancelled ?? false)) {
      if (acquired) semaphore?.release();
      handler.reject(cancelToken!.cancelError!);
      return;
    }
    options.extra[_semaphoreExtraKey] = semaphore == null
        ? null
        : _SemaphoreLease(semaphore);
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    release(response.requestOptions);
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    release(err.response?.requestOptions ?? err.requestOptions);
    handler.next(err);
  }

  static void release(RequestOptions options) {
    (options.extra[_semaphoreExtraKey] as _SemaphoreLease?)?.release();
  }
}
