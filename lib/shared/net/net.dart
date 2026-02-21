import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:senpwai/shared/net/user_agents.dart';

class GlobalDio {
  GlobalDio._();

  static Dio? _instance;

  static Dio getInstance() {
    if (_instance != null) {
      return _instance!;
    }

    final userAgent = getRandomUserAgent();
    final options = BaseOptions(headers: {"User-Agent": userAgent});
    final dio = Dio(options);
    dio.interceptors
      ..add(
        PrettyDioLogger(
          enabled: kDebugMode,
          requestHeader: true,
          responseBody: false,
        ),
      )
      ..add(
        DioCacheInterceptor(
          options: CacheOptions(
            store: MemCacheStore(),
            policy: CachePolicy.forceCache,
            // TODO: Make this configurable
            maxStale: const Duration(hours: 1),
          ),
        ),
      );
    _instance = dio;
    return dio;
  }
}
