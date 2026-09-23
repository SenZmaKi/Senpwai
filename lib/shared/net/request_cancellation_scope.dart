import 'dart:async';

import 'package:dio/dio.dart';

final _cancelTokenZoneKey = Object();

class RequestScopeCancelled implements Exception {
  const RequestScopeCancelled();
}

Future<T> runWithRequestCancelToken<T>(
  CancelToken cancelToken,
  Future<T> Function() operation,
) => runZoned(operation, zoneValues: {_cancelTokenZoneKey: cancelToken});

void throwIfRequestScopeCancelled() {
  final cancelToken = Zone.current[_cancelTokenZoneKey] as CancelToken?;
  if (cancelToken?.isCancelled ?? false) {
    throw const RequestScopeCancelled();
  }
}

class ScopedCancelTokenInterceptor extends Interceptor {
  const ScopedCancelTokenInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.cancelToken ??= Zone.current[_cancelTokenZoneKey] as CancelToken?;
    handler.next(options);
  }
}
