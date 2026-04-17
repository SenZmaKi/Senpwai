import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:senpwai/shared/net/interceptors/cf_bypass.dart';
import 'package:senpwai/shared/net/interceptors/concurrency.dart';
import 'package:senpwai/shared/net/interceptors/rate_limit.dart';
import 'package:senpwai/shared/net/net_config.dart';

class GlobalDio {
  GlobalDio._();

  static Dio? _instance;
  static final CookieJar _cookieJar = CookieJar();
  static CfBypassInterceptor? _cfBypassInterceptor;

  static CookieJar get cookieJar => _cookieJar;
  static CfBypassInterceptor? get cfBypassInterceptor => _cfBypassInterceptor;

  static Dio getInstance() {
    if (_instance != null) {
      return _instance!;
    }

    _instance = Dio();
    _cfBypassInterceptor = CfBypassInterceptor(
      dio: _instance!,
      cookieJar: _cookieJar,
    );
    _instance!.interceptors.add(RateLimitInterceptor(_instance!));
    // Empirically: nyaa.si returns HTTP 429 at ~7 concurrent requests.
    // Cap at 5 to leave comfortable headroom.
    _instance!.interceptors.add(ConcurrencyInterceptor({'nyaa.si': 5}));
    _instance!.interceptors.add(_cfBypassInterceptor!);
    _instance!.interceptors.add(CookieManager(_cookieJar));
    _instance!.interceptors.add(
      PrettyDioLogger(
        enabled: kDebugMode,
        requestHeader: true,
        responseBody: false,
      ),
    );
    NetConfig.getInstance().attachToDio(_instance!);
    return _instance!;
  }
}
