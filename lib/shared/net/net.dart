import 'package:cf_bypass/cf_bypass.dart' hide LoggerExtensions;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:senpwai/shared/net/cf_egress_identity.dart';
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
  static ConcurrencyInterceptor? _concurrencyInterceptor;

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

  static void updateHostConcurrencyLimits(Map<String, int> hostLimits) {
    _concurrencyInterceptor?.updateHostLimits(hostLimits);
  }

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
    final egressResolver = CfEgressIdentityResolver();
    final hasProfiles = await cfBypassSessionStore.hasProfiles();
    final egressIdentity = hasProfiles ? await egressResolver.resolve() : null;
    final networkKey = egressIdentity?.key;
    final cfSessions = networkKey == null
        ? const <String, CfBypassHostSession>{}
        : await cfBypassSessionStore.loadForNetwork(networkKey);
    final storedHosts = await cfBypassSessionStore.hosts();
    await _activateSessions(cookieJar, storedHosts, cfSessions);
    _cookieJar = cookieJar;
    _instance = Dio();
    _cfBypassInterceptor = CfBypassInterceptor(
      dio: _instance!,
      cookieJar: cookieJar,
      sessionStore: cfBypassSessionStore,
      initialSessions: cfSessions,
      networkKey: networkKey,
      egressResolver: egressResolver,
    );
    _connectivityInterceptor = ConnectivityInterceptor(_instance!);
    _instance!.interceptors.add(RateLimitInterceptor(_instance!));
    _concurrencyInterceptor = ConcurrencyInterceptor(const {});
    _instance!.interceptors.add(_concurrencyInterceptor!);
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

  static Future<void> _activateSessions(
    CookieJar cookieJar,
    Set<String> storedHosts,
    Map<String, CfBypassHostSession> sessions,
  ) async {
    for (final host in storedHosts) {
      final uri = Uri.https(host, '/');
      await cookieJar.delete(uri, true);
      final session = sessions[host];
      if (session == null) continue;
      await cookieJar.saveFromResponse(uri, [
        for (final storedCookie in session.cookies) ...[
          _restoreCookie(storedCookie, fallbackDomain: host),
          if (CfCookieHelper.isBypassProofCookie(storedCookie.name))
            _restoreHostRootCookie(storedCookie),
        ],
      ]);
    }
  }

  static Cookie _restoreCookie(
    CfBypassStoredCookie storedCookie, {
    required String fallbackDomain,
  }) {
    return Cookie(storedCookie.name, storedCookie.value)
      ..domain = storedCookie.domain.isEmpty
          ? fallbackDomain
          : storedCookie.domain
      ..path = storedCookie.path
      ..secure = storedCookie.isSecure ?? false
      ..httpOnly = storedCookie.isHttpOnly ?? false
      ..expires = storedCookie.expires;
  }

  static Cookie _restoreHostRootCookie(CfBypassStoredCookie storedCookie) {
    return Cookie(storedCookie.name, storedCookie.value)
      ..path = '/'
      ..secure = storedCookie.isSecure ?? false
      ..httpOnly = storedCookie.isHttpOnly ?? false
      ..expires = storedCookie.expires;
  }

  static Dio getInstance() {
    final resolved = _instance;
    if (resolved == null) {
      throw StateError('GlobalDio.initialize must be called first.');
    }
    return resolved;
  }
}
