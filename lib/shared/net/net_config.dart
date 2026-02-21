import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:senpwai/shared/net/user_agents.dart';

class NetConfig {
  final maxConnectionsPerHost = 25;
  final idleTimeout = Duration(minutes: 3);
  final cacheMaxStale = Duration(hours: 1);
  final userAgent = getRandomUserAgent();

  static NetConfig? _instance;

  static NetConfig getInstance() {
    return _instance ??= NetConfig();
  }

  void attachToDio(Dio dio) {
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () =>
        HttpClient()
          ..maxConnectionsPerHost = maxConnectionsPerHost
          ..idleTimeout = idleTimeout;
    dio.interceptors.add(
      DioCacheInterceptor(
        options: CacheOptions(
          store: MemCacheStore(),
          policy: CachePolicy.forceCache,
          maxStale: cacheMaxStale,
        ),
      ),
    );
    dio.options.headers["User-Agent"] = userAgent;
  }
}
