import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:senpwai/shared/net/user_agents.dart';

Dio defaultDio() {
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
  return dio;
}
