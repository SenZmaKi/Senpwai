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
    _semaphores.removeWhere((host, _) => _hostLimits[host] != hostLimits[host]);
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
    options.extra[_semaphoreExtraKey] = semaphore;
    await semaphore?.acquire();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    (response.requestOptions.extra[_semaphoreExtraKey] as _Semaphore?)
        ?.release();
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    ((err.response?.requestOptions ?? err.requestOptions)
                .extra[_semaphoreExtraKey]
            as _Semaphore?)
        ?.release();
    handler.next(err);
  }
}
