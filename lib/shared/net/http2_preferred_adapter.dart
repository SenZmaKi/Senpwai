import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:http2/transport.dart';

/// Prefers HTTP/2 for every request and falls back to the configured adapter.
///
/// [Http2Adapter] owns its HTTP/2 connections but does not close its fallback
/// adapter, so this wrapper owns and closes both transports.
class Http2PreferredAdapter implements HttpClientAdapter {
  final HttpClientAdapter fallbackAdapter;
  late final Http2Adapter _http2Adapter;
  final Set<String> _http1OnlyOrigins = {};

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
  ) async {
    final origin = _origin(options.uri);
    if (_http1OnlyOrigins.contains(origin)) {
      return fallbackAdapter.fetch(options, requestStream, cancelFuture);
    }

    try {
      return await _http2Adapter.fetch(options, requestStream, cancelFuture);
    } on TransportConnectionException {
      if (!_canReplay(options, requestStream)) rethrow;

      _http1OnlyOrigins.add(origin);
      return fallbackAdapter.fetch(options, null, cancelFuture);
    }
  }

  bool _canReplay(RequestOptions options, Stream<Uint8List>? requestStream) =>
      requestStream == null &&
      (options.method == 'GET' || options.method == 'HEAD');

  String _origin(Uri uri) => '${uri.scheme}://${uri.host}:${uri.port}';

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
