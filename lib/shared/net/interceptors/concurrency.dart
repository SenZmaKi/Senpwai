import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';

/// Counting semaphore — limits how many operations run at the same time.
class _Semaphore {
  final int _max;
  int _active = 0;
  final Queue<void Function()> _waiters = Queue();

  _Semaphore(this._max);

  Future<void> acquire() async {
    if (_active < _max) {
      _active++;
      return;
    }
    final completer = Completer<void>();
    _waiters.add(completer.complete);
    await completer.future;
    // The slot was transferred by release(); do NOT increment _active again.
  }

  void release() {
    if (_waiters.isNotEmpty) {
      // Transfer the slot directly to the next waiter — don't decrement.
      _waiters.removeFirst().call();
    } else {
      _active--;
    }
  }
}

/// Limits the number of concurrent in-flight HTTP requests **per host**.
///
/// Only hosts explicitly registered in [hostLimits] are affected; all other
/// requests pass through without any concurrency control.
///
/// Example — cap nyaa.si at 5 concurrent requests:
/// ```dart
/// ConcurrencyInterceptor({'nyaa.si': 5})
/// ```
class ConcurrencyInterceptor extends Interceptor {
  final Map<String, int> hostLimits;
  final Map<String, _Semaphore> _semaphores = {};

  ConcurrencyInterceptor(this.hostLimits);

  _Semaphore? _semaphoreFor(String host) {
    final limit = hostLimits[host];
    if (limit == null) return null;
    return _semaphores.putIfAbsent(host, () => _Semaphore(limit));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await _semaphoreFor(options.uri.host)?.acquire();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _semaphoreFor(response.requestOptions.uri.host)?.release();
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    _semaphoreFor(err.requestOptions.uri.host)?.release();
    handler.next(err);
  }
}
