import 'dart:async';

import 'package:dio/dio.dart';

final _cancelTokenZoneKey = Object();

Future<T> runWithRequestCancelToken<T>(
  CancelToken cancelToken,
  Future<T> Function() operation,
) => runZoned(operation, zoneValues: {_cancelTokenZoneKey: cancelToken});

class ScopedCancelTokenInterceptor extends Interceptor {
  const ScopedCancelTokenInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.cancelToken ??= Zone.current[_cancelTokenZoneKey] as CancelToken?;
    handler.next(options);
  }
}
