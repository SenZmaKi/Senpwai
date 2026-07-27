import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class HttpTransportConfig {
  static const defaultMaxConnectionsPerHost = 25;
  static const defaultIdleTimeout = Duration(minutes: 3);

  final int maxConnectionsPerHost;
  final Duration idleTimeout;
  final String userAgent;

  const HttpTransportConfig({
    required this.userAgent,
    this.maxConnectionsPerHost = defaultMaxConnectionsPerHost,
    this.idleTimeout = defaultIdleTimeout,
  });

  void attachToDio(Dio dio) {
    final adapter = dio.httpClientAdapter;
    if (adapter is IOHttpClientAdapter) {
      adapter.createHttpClient = () => HttpClient()
        ..maxConnectionsPerHost = maxConnectionsPerHost
        ..idleTimeout = idleTimeout;
    }
    dio.options.headers['User-Agent'] = userAgent;
  }
}
