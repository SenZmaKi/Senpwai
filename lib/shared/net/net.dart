import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:senpwai/shared/net/browser_transport/browser_http_client_adapter.dart';
import 'package:senpwai/shared/net/browser_transport/browser_transport.dart';
import 'package:senpwai/shared/net/browser_transport/hybrid_http_client_adapter.dart';
import 'package:senpwai/shared/net/browser_transport/routing.dart';
import 'package:senpwai/shared/net/http2_preferred_adapter.dart';
import 'package:senpwai/shared/net/interceptors/connectivity.dart';
import 'package:senpwai/shared/net/interceptors/concurrency.dart';
import 'package:senpwai/shared/net/interceptors/cookie_manager.dart';
import 'package:senpwai/shared/net/interceptors/rate_limit.dart';
import 'package:senpwai/shared/net/net_config.dart';
import 'package:senpwai/shared/net/request_cancellation_scope.dart';
import 'package:senpwai/shared/persistence/app_paths.dart';

class GlobalDio {
  GlobalDio._();

  static Dio? _instance;
  static CookieJar? _cookieJar;
  static ConnectivityInterceptor? _connectivityInterceptor;
  static ConcurrencyInterceptor? _concurrencyInterceptor;
  static final BrowserRoutingPolicy browserRoutingPolicy =
      BrowserRoutingPolicy();

  static CookieJar get cookieJar {
    final resolved = _cookieJar;
    if (resolved == null) {
      throw StateError('GlobalDio.initialize must be called first.');
    }
    return resolved;
  }

  static ConnectivityInterceptor? get connectivityInterceptor =>
      _connectivityInterceptor;

  static void updateHostConcurrencyLimits(Map<String, int> hostLimits) {
    _concurrencyInterceptor?.updateHostLimits(hostLimits);
  }

  static void updateBrowserOrigins(Map<String, Uri> origins) {
    browserRoutingPolicy.replaceBrowserOrigins(origins);
    BrowserTransportService.instance.retainHosts(origins.keys);
  }

  static Future<void> initialize({required AppPaths paths}) async {
    if (_instance != null) {
      return;
    }

    final cookieJar = PersistCookieJar(
      storage: FileStorage(paths.networkCookiesDirectory.path),
    );
    _cookieJar = cookieJar;
    _instance = Dio();
    _instance!.interceptors.add(const ScopedCancelTokenInterceptor());
    _connectivityInterceptor = ConnectivityInterceptor(_instance!);
    _instance!.interceptors.add(RateLimitInterceptor(_instance!));
    _concurrencyInterceptor = ConcurrencyInterceptor(const {});
    _instance!.interceptors.add(_concurrencyInterceptor!);
    _instance!.interceptors.add(_connectivityInterceptor!);
    _instance!.interceptors.add(
      AppCookieManager(cookieJar, routingPolicy: browserRoutingPolicy),
    );
    _instance!.interceptors.add(
      PrettyDioLogger(
        enabled: kDebugMode,
        requestHeader: false,
        responseBody: false,
      ),
    );
    NetConfig.getInstance().attachToDio(_instance!);
    preferHttp2(_instance!);
    final nativeAdapter = _instance!.httpClientAdapter;
    _instance!.httpClientAdapter = HybridHttpClientAdapter(
      nativeAdapter: nativeAdapter,
      browserAdapter: BrowserHttpClientAdapter(
        BrowserTransportService.instance,
        routingPolicy: browserRoutingPolicy,
      ),
      routingPolicy: browserRoutingPolicy,
    );
  }

  static Dio getInstance() {
    final resolved = _instance;
    if (resolved == null) {
      throw StateError('GlobalDio.initialize must be called first.');
    }
    return resolved;
  }
}
