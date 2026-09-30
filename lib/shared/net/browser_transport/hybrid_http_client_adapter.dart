import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:senpwai/shared/net/browser_transport/routing.dart';

class HybridHttpClientAdapter implements HttpClientAdapter {
  final HttpClientAdapter nativeAdapter;
  final HttpClientAdapter browserAdapter;
  final BrowserRoutingPolicy routingPolicy;

  const HybridHttpClientAdapter({
    required this.nativeAdapter,
    required this.browserAdapter,
    required this.routingPolicy,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final adapter = routingPolicy.useBrowser(options)
        ? browserAdapter
        : nativeAdapter;
    return adapter.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {
    nativeAdapter.close(force: force);
    browserAdapter.close(force: force);
  }
}
