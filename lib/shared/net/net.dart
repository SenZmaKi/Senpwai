import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:senpwai/shared/net/http2_preferred_adapter.dart';
import 'package:senpwai/shared/net/interceptors/cf_bypass.dart';
import 'package:senpwai/shared/net/interceptors/connectivity.dart';
import 'package:senpwai/shared/net/interceptors/concurrency.dart';
import 'package:senpwai/shared/net/interceptors/cookie_manager.dart';
import 'package:senpwai/shared/net/interceptors/rate_limit.dart';
import 'package:senpwai/shared/net/net_config.dart';
import 'package:senpwai/shared/persistence/app_paths.dart';
import 'package:senpwai/shared/persistence/cf_bypass_session_store.dart';

class GlobalDio {
  GlobalDio._();

  static Dio? _instance;
  static CookieJar? _cookieJar;
  static CfBypassInterceptor? _cfBypassInterceptor;
  static ConnectivityInterceptor? _connectivityInterceptor;

  static CookieJar get cookieJar {
    final resolved = _cookieJar;
    if (resolved == null) {
      throw StateError('GlobalDio.initialize must be called first.');
    }
    return resolved;
  }

  static CfBypassInterceptor? get cfBypassInterceptor => _cfBypassInterceptor;
  static ConnectivityInterceptor? get connectivityInterceptor =>
      _connectivityInterceptor;

  static Future<void> initialize({
    required AppPaths paths,
    required CfBypassSessionStore cfBypassSessionStore,
  }) async {
    if (_instance != null) {
      return;
    }

    final cookieJar = PersistCookieJar(
      storage: FileStorage(paths.networkCookiesDirectory.path),
    );
    final cfSessions = await cfBypassSessionStore.load();
    _cookieJar = cookieJar;
    _instance = Dio();
    _cfBypassInterceptor = CfBypassInterceptor(
      dio: _instance!,
      cookieJar: cookieJar,
      sessionStore: cfBypassSessionStore,
      initialSessions: cfSessions,
    );
    _connectivityInterceptor = ConnectivityInterceptor(_instance!);
    _instance!.interceptors.add(RateLimitInterceptor(_instance!));
    // Empirically: nyaa.si returns HTTP 429 at ~7 concurrent requests.
    // Cap at 5 to leave comfortable headroom.
    _instance!.interceptors.add(ConcurrencyInterceptor({'nyaa.si': 5}));
    _instance!.interceptors.add(_cfBypassInterceptor!);
    _instance!.interceptors.add(_connectivityInterceptor!);
    _instance!.interceptors.add(AppCookieManager(cookieJar));
    _instance!.interceptors.add(
      PrettyDioLogger(
        enabled: kDebugMode,
        requestHeader: false,
        responseBody: false,
      ),
    );
    NetConfig.getInstance().attachToDio(_instance!);
    preferHttp2(_instance!);
  }

  static Dio getInstance() {
    final resolved = _instance;
    if (resolved == null) {
      throw StateError('GlobalDio.initialize must be called first.');
    }
    return resolved;
  }
}
