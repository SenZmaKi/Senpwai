import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';

/// Prefers HTTP/2 for every request and falls back to the configured adapter.
///
/// [Http2Adapter] owns its HTTP/2 connections but does not close its fallback
/// adapter, so this wrapper owns and closes both transports.
class Http2PreferredAdapter implements HttpClientAdapter {
  final HttpClientAdapter fallbackAdapter;
  late final Http2Adapter _http2Adapter;

  Http2PreferredAdapter({
    required this.fallbackAdapter,
    Duration idleTimeout = const Duration(minutes: 3),
  }) {
    _http2Adapter = Http2Adapter(
      ConnectionManager(idleTimeout: idleTimeout),
      fallbackAdapter: fallbackAdapter,
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _http2Adapter.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {
    _http2Adapter.close(force: force);
    fallbackAdapter.close(force: force);
  }
}

void preferHttp2(Dio dio) {
  dio.httpClientAdapter = Http2PreferredAdapter(
    fallbackAdapter: dio.httpClientAdapter,
  );
}
