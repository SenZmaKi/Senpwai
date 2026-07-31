import 'dart:io';

import 'package:cf_bypass/cf_bypass.dart' hide LoggerExtensions;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/cf_egress_identity.dart';
import 'package:senpwai/shared/net/net_config.dart';
import 'package:senpwai/shared/persistence/cf_bypass_session_store.dart';

final _log = Logger("senpwai.net.interceptors.cf_bypass");

const _cfBypassRetriedExtraKey = 'cfBypassRetried';
const _cfBypassValidationExtraKey = 'cfBypassValidation';
const _cfBypassSessionAppliedExtraKey = 'cfBypassSessionApplied';
const _cfStaleSessionRetriedExtraKey = 'cfStaleSessionRetried';
const _cfNetworkProfileRetriedExtraKey = 'cfNetworkProfileRetried';
const skipCfBypassExtraKey = 'skipCfBypass';
int _nextInterceptorId = 0;

/// Callback the UI layer provides to solve a CF challenge.
/// Takes the challenge context, returns the bypass result from the WebView.
typedef CfBypassSolver =
    Future<CfBypassResult> Function(CfBypassChallenge challenge);

class CfBypassChallenge {
  final String url;
  final Future<bool> Function(CfBypassResult result) validate;

  const CfBypassChallenge({required this.url, required this.validate});
}

/// Dio interceptor that detects CloudFlare protection on error responses
/// and delegates challenge solving to a [CfBypassSolver] callback.
///
/// On successful bypass, cookies and user-agent are applied to the [CookieJar]
/// and the original request is retried transparently.
class CfBypassInterceptor extends Interceptor {
  final Dio dio;
  final CookieJar cookieJar;
  final CfBypassSessionStore sessionStore;
  final CfEgressIdentityResolver egressResolver;
  String? _networkKey;
  late final int _interceptorId = ++_nextInterceptorId;
  CfBypassSolver? _solver;
  final Map<String, String> _userAgentsByHost = {};
  final Map<String, Future<CfBypassResult>> _bypassByHost = {};
  final Map<String, Future<void>> _sessionResetByHost = {};
  final Set<String> _bypassedHosts = {};
  Future<bool>? _networkRefresh;

  CfBypassInterceptor({
    required this.dio,
    required this.cookieJar,
    required this.sessionStore,
    required String? networkKey,
    required this.egressResolver,
    required Map<String, CfBypassHostSession> initialSessions,
  }) : _networkKey = networkKey {
    for (final entry in initialSessions.entries) {
      _bypassedHosts.add(entry.key);
      final userAgent = entry.value.userAgent;
      if (userAgent != null && userAgent.isNotEmpty) {
        _userAgentsByHost[entry.key] = userAgent;
      }
    }
    _log.infoWithMetadata(
      "Created CF bypass interceptor",
      metadata: {
        "interceptorId": _interceptorId,
        "networkId": _shortNetworkId(networkKey),
        "persistedHosts": initialSessions.keys.toList(),
      },
    );
  }

  /// Sets the solver callback. Typically called by the UI layer once
  /// it has a navigation context to show the [CfWebView].
  void setSolver(CfBypassSolver? solver) {
    _solver = solver;
    _log.infoWithMetadata(
      "CF bypass solver ${solver != null ? 'set' : 'cleared'}",
      metadata: {"interceptorId": _interceptorId},
    );
  }

  void clearRememberedSessions() {
    _userAgentsByHost.clear();
    _bypassedHosts.clear();
    _networkKey = null;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[skipCfBypassExtraKey] == true) {
      handler.next(options);
      return;
    }
    final isValidationRequest = _isValidationRequest(options);
    final userAgent = isValidationRequest
        ? null
        : _userAgentsByHost[options.uri.host];
    if (!isValidationRequest &&
        (userAgent != null || _hasBypassSession(options.uri.host))) {
      options.extra[_cfBypassSessionAppliedExtraKey] = true;
      _applyBypassReplayHeaders(
        options.headers,
        options.uri,
        userAgent: userAgent,
      );
    }
    if (isValidationRequest) {
      _log.infoWithMetadata(
        "CF request session state before cookie manager",
        metadata: {
          "url": options.uri.toString(),
          "interceptorId": _interceptorId,
          "host": options.uri.host,
          "isValidation": isValidationRequest,
          "hasBypassSession": _hasBypassSession(options.uri.host),
          "hasRememberedUserAgent": userAgent != null,
          "cookieNames": _cookieNamesFromHeaders(options.headers),
        },
      );
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.requestOptions.extra[skipCfBypassExtraKey] == true) {
      handler.next(err);
      return;
    }
    final response = err.response;
    if (response == null) {
      handler.next(err);
      return;
    }

    if (_isValidationRequest(err.requestOptions)) {
      handler.next(err);
      return;
    }

    final alreadyRetried =
        err.requestOptions.extra[_cfBypassRetriedExtraKey] == true;

    final statusCode = response.statusCode ?? 0;
    final body = response.data is String ? response.data as String : null;
    final url = err.requestOptions.uri.toString();

    final detection = CfDetector.detect(
      CfDetectionRequest(
        url: url,
        statusCode: statusCode,
        body: body,
        source: "dio",
      ),
    );

    if (!detection.isProtected) {
      handler.next(err);
      return;
    }

    _log.infoWithMetadata(
      "CloudFlare protection detected",
      metadata: {
        "url": url,
        "interceptorId": _interceptorId,
        "kind": detection.kind.name,
        "indicators": detection.matchedIndicators,
        "hasBypassSession": _hasBypassSession(err.requestOptions.uri.host),
        "requestCookieNames": _cookieNamesFromHeaders(
          err.requestOptions.headers,
        ),
        "requestHasUserAgent": err.requestOptions.headers.containsKey(
          "User-Agent",
        ),
      },
    );

    final networkProfileAlreadyRetried =
        err.requestOptions.extra[_cfNetworkProfileRetriedExtraKey] == true;
    if (!networkProfileAlreadyRetried &&
        await _refreshNetworkProfileIfChanged()) {
      try {
        final retryResponse = await dio.fetch<dynamic>(
          _buildNetworkProfileRetryOptions(err.requestOptions),
        );
        handler.resolve(retryResponse);
      } catch (error) {
        handler.next(error is DioException ? error : err);
      }
      return;
    }

    if (detection.kind == CfProtectionKind.blocked) {
      final staleSessionAlreadyRetried =
          err.requestOptions.extra[_cfStaleSessionRetriedExtraKey] == true;
      final requestUsedBypassSession =
          err.requestOptions.extra[_cfBypassSessionAppliedExtraKey] == true;
      if (requestUsedBypassSession &&
          !staleSessionAlreadyRetried &&
          !alreadyRetried) {
        final host = err.requestOptions.uri.host;
        _log.warningWithMetadata(
          "CF blocked remembered session — retrying clean",
          metadata: {"url": url, "host": host, "interceptorId": _interceptorId},
        );

        try {
          await _resetHostSession(err.requestOptions.uri);
          final retryResponse = await dio.fetch<dynamic>(
            _buildCleanRetryOptions(err.requestOptions),
          );
          handler.resolve(retryResponse);
        } catch (e, stack) {
          _log.warningWithMetadata(
            "CF clean retry failed",
            metadata: {
              "url": url,
              "host": host,
              "interceptorId": _interceptorId,
              "error": e.toString(),
              "stackTrace": stack.toString(),
            },
          );
          handler.next(e is DioException ? e : err);
        }
        return;
      }

      _log.warningWithMetadata(
        "CloudFlare hard block — cannot bypass",
        metadata: {
          "url": url,
          "interceptorId": _interceptorId,
          "cleanRetryAttempted": staleSessionAlreadyRetried,
        },
      );
      handler.next(
        DioException(
          requestOptions: err.requestOptions,
          response: response,
          error: detection.exception,
          type: DioExceptionType.unknown,
          message: "CloudFlare blocked: ${detection.matchedIndicators}",
        ),
      );
      return;
    }

    if (alreadyRetried) {
      _log.warningWithMetadata(
        "CF bypass already retried, passing through",
        metadata: {
          "url": err.requestOptions.uri.toString(),
          "interceptorId": _interceptorId,
        },
      );
      handler.next(err);
      return;
    }

    if (_solver == null) {
      _log.warning("CF challenge detected but no solver set — cannot bypass");
      handler.next(err);
      return;
    }

    try {
      final result = await _solveBypass(
        err.requestOptions.uri.host,
        url,
        err.requestOptions,
      );

      if (!result.success) {
        _log.warningWithMetadata(
          "CF bypass failed",
          metadata: {
            "url": url,
            "interceptorId": _interceptorId,
            "error": result.error,
          },
        );
        handler.next(err);
        return;
      }

      _log.infoWithMetadata(
        "CF bypass succeeded",
        metadata: {
          "url": url,
          "interceptorId": _interceptorId,
          "hasUserAgent": result.userAgent?.isNotEmpty == true,
          "cookieCount": result.cookies.length,
          "duration": result.duration?.inMilliseconds,
        },
      );

      await _applyCookies(result, err.requestOptions.uri);
      _bypassedHosts.add(err.requestOptions.uri.host);

      if (result.userAgent != null) {
        _userAgentsByHost[err.requestOptions.uri.host] = result.userAgent!;
      }
      await _rememberSession(err.requestOptions.uri.host, result);

      final retryOptions = _buildBypassReplayOptions(
        err.requestOptions,
        userAgent: result.userAgent,
        validation: false,
        extra: {_cfBypassRetriedExtraKey: true},
      );

      final retryResponse = await dio.fetch<dynamic>(retryOptions);
      handler.resolve(retryResponse);
    } catch (e, stack) {
      _log.severeWithMetadata(
        "CF bypass solver threw",
        error: e,
        stackTrace: stack,
        metadata: {"url": url, "interceptorId": _interceptorId},
      );
      handler.next(err);
    }
  }

  Future<CfBypassResult> _solveBypass(
    String host,
    String url,
    RequestOptions requestOptions,
  ) {
    final existingBypass = _bypassByHost[host];
    if (existingBypass != null) {
      _log.infoWithMetadata(
        "Waiting for in-flight CF bypass",
        metadata: {"host": host, "url": url, "interceptorId": _interceptorId},
      );
      return existingBypass;
    }

    final solver = _solver;
    if (solver == null) {
      throw StateError("CF bypass solver is not set");
    }

    _log.infoWithMetadata(
      "Initiating CF bypass solve",
      metadata: {"host": host, "url": url, "interceptorId": _interceptorId},
    );

    final bypass =
        solver(
          CfBypassChallenge(
            url: url,
            validate: (result) => validateBypassResult(requestOptions, result),
          ),
        ).whenComplete(() {
          _bypassByHost.remove(host);
        });
    _bypassByHost[host] = bypass;
    return bypass;
  }

  Future<bool> validateBypassResult(
    RequestOptions requestOptions,
    CfBypassResult result,
  ) async {
    if (!result.success) return false;

    await _applyCookies(result, requestOptions.uri);

    final validationOptions = _buildBypassReplayOptions(
      requestOptions,
      userAgent: result.userAgent,
      validation: true,
    );

    try {
      final response = await dio.fetch<dynamic>(validationOptions);

      final body = response.data is String ? response.data as String : null;
      final flatHeaders = <String, String>{};
      response.headers.forEach(
        (name, values) => flatHeaders[name.toLowerCase()] = values.join(', '),
      );
      final detection = CfDetector.detect(
        CfDetectionRequest(
          url: response.realUri.toString(),
          statusCode: response.statusCode ?? 0,
          body: body,
          headers: flatHeaders,
          source: "dio-validation",
        ),
      );
      final statusCode = response.statusCode ?? 0;
      final verified =
          statusCode >= 200 &&
          statusCode < 400 &&
          detection.kind == CfProtectionKind.none;

      _log.infoWithMetadata(
        verified
            ? "CF bypass validation passed"
            : "CF bypass validation failed",
        metadata: {
          "url": requestOptions.uri.toString(),
          "interceptorId": _interceptorId,
          "statusCode": statusCode,
          "kind": detection.kind.name,
          "indicators": detection.matchedIndicators,
          "cookieNames": _cookieNamesFromHeaders(validationOptions.headers),
        },
      );
      return verified;
    } catch (e, stack) {
      _log.warningWithMetadata(
        "CF bypass validation request failed",
        metadata: {
          "url": requestOptions.uri.toString(),
          "interceptorId": _interceptorId,
          "error": e.toString(),
          "stackTrace": stack.toString(),
        },
      );
      return false;
    }
  }

  bool _isValidationRequest(RequestOptions options) =>
      options.extra[_cfBypassValidationExtraKey] == true;

  bool _hasBypassSession(String host) => _bypassedHosts.contains(host);

  Future<void> _rememberSession(String host, CfBypassResult result) async {
    final networkKey = await _ensureNetworkKey();
    if (networkKey == null) {
      _log.warningWithMetadata(
        "CF bypass session will not persist because network lookup failed",
        metadata: {"host": host, "interceptorId": _interceptorId},
      );
      return;
    }

    await sessionStore.rememberHost(
      host,
      networkKey: networkKey,
      userAgent: _userAgentsByHost[host],
      cookies: [
        for (final cookie in result.cookies)
          CfBypassStoredCookie(
            name: cookie.name,
            value: cookie.value,
            domain: cookie.domain,
            path: cookie.path,
            isSecure: cookie.isSecure,
            isHttpOnly: cookie.isHttpOnly,
            expires: cookie.expires,
          ),
      ],
    );
    _log.infoWithMetadata(
      "Remembered CF bypass session",
      metadata: {
        "host": host,
        "networkId": _shortNetworkId(networkKey),
        "interceptorId": _interceptorId,
        "hasUserAgent": _userAgentsByHost.containsKey(host),
        "cookieNames": result.cookies.map((cookie) => cookie.name).toList(),
      },
    );
  }

  Future<String?> _ensureNetworkKey() async {
    final current = _networkKey;
    if (current != null) return current;
    final identity = await egressResolver.resolve();
    _networkKey = identity?.key;
    return _networkKey;
  }

  Future<bool> _refreshNetworkProfileIfChanged() {
    final inFlight = _networkRefresh;
    if (inFlight != null) return inFlight;

    final refresh = _doRefreshNetworkProfile().whenComplete(
      () => _networkRefresh = null,
    );
    _networkRefresh = refresh;
    return refresh;
  }

  Future<bool> _doRefreshNetworkProfile() async {
    final identity = await egressResolver.resolve(forceRefresh: true);
    if (identity == null || identity.key == _networkKey) return false;

    final sessions = await sessionStore.loadForNetwork(identity.key);
    final storedHosts = await sessionStore.hosts();
    await _activateNetworkSessions(storedHosts, sessions);
    _networkKey = identity.key;
    _log.infoWithMetadata(
      "Activated CF sessions for changed network",
      metadata: {
        "interceptorId": _interceptorId,
        "networkId": _shortNetworkId(identity.key),
        "persistedHosts": sessions.keys.toList(),
      },
    );
    return true;
  }

  Future<void> _activateNetworkSessions(
    Set<String> storedHosts,
    Map<String, CfBypassHostSession> sessions,
  ) async {
    _bypassedHosts.clear();
    _userAgentsByHost.clear();

    for (final host in storedHosts) {
      final uri = Uri.https(host, '/');
      await cookieJar.delete(uri, true);
      final session = sessions[host];
      if (session == null) continue;

      final cookies = <Cookie>[
        for (final storedCookie in session.cookies) ...[
          _toStoredCookie(storedCookie, fallbackDomain: host),
          if (CfCookieHelper.isBypassProofCookie(storedCookie.name))
            _toStoredHostRootCookie(storedCookie),
        ],
      ];
      if (cookies.isNotEmpty) await cookieJar.saveFromResponse(uri, cookies);
      _bypassedHosts.add(host);
      final userAgent = session.userAgent;
      if (userAgent != null && userAgent.isNotEmpty) {
        _userAgentsByHost[host] = userAgent;
      }
    }
  }

  Future<void> _resetHostSession(Uri uri) {
    final host = uri.host;
    final existingReset = _sessionResetByHost[host];
    if (existingReset != null) return existingReset;

    _bypassedHosts.remove(host);
    _userAgentsByHost.remove(host);
    final reset =
        Future.wait([
              if (_networkKey case final networkKey?)
                sessionStore.forgetHost(host, networkKey: networkKey),
              cookieJar.delete(uri, true),
            ])
            .then<void>((_) {
              _log.infoWithMetadata(
                "Cleared rejected CF bypass session",
                metadata: {"host": host, "interceptorId": _interceptorId},
              );
            })
            .whenComplete(() {
              _sessionResetByHost.remove(host);
            });
    _sessionResetByHost[host] = reset;
    return reset;
  }

  List<String> _cookieNamesFromHeaders(Map<String, dynamic> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == HttpHeaders.cookieHeader) {
        return _cookieNamesFromHeaderValue(entry.value);
      }
    }
    return const [];
  }

  List<String> _cookieNamesFromHeaderValue(Object? headerValue) {
    if (headerValue == null) return const [];
    final text = headerValue is Iterable
        ? headerValue.map((value) => value.toString()).join('; ')
        : headerValue.toString();
    return _cookiePairsFromHeaderText(text).keys.toList()..sort();
  }

  Map<String, String> _cookiePairsFromHeaderText(String text) {
    final pairs = <String, String>{};
    for (final part in text.split(';')) {
      final trimmed = part.trim();
      final eqIdx = trimmed.indexOf('=');
      if (eqIdx <= 0) continue;
      final name = trimmed.substring(0, eqIdx).trim();
      final value = trimmed.substring(eqIdx + 1).trim();
      if (name.isEmpty) continue;
      pairs[name] = value;
    }
    return pairs;
  }

  Map<String, dynamic> _buildValidationExtra(Map<String, dynamic> extra) {
    return {..._buildNoCacheExtra(extra), _cfBypassValidationExtraKey: true};
  }

  Map<String, dynamic> _buildNoCacheExtra(Map<String, dynamic> extra) {
    return {
      ...extra,
      ...NetConfig.getInstance()
          .buildCacheOptions(policy: CachePolicy.noCache)
          .toExtra(),
    };
  }

  RequestOptions _buildCleanRetryOptions(RequestOptions requestOptions) {
    final headers = Map<String, dynamic>.of(requestOptions.headers);
    _removeHeader(headers, HttpHeaders.cookieHeader);

    final defaultUserAgent = _headerValue(
      dio.options.headers,
      HttpHeaders.userAgentHeader,
    );
    if (defaultUserAgent == null) {
      _removeHeader(headers, HttpHeaders.userAgentHeader);
    } else {
      headers[HttpHeaders.userAgentHeader] = defaultUserAgent;
    }

    final extra = _buildNoCacheExtra(requestOptions.extra)
      ..remove(_cfBypassSessionAppliedExtraKey)
      ..remove(_cfBypassRetriedExtraKey)
      ..[_cfStaleSessionRetriedExtraKey] = true;

    return requestOptions.copyWith(headers: headers, extra: extra);
  }

  RequestOptions _buildNetworkProfileRetryOptions(
    RequestOptions requestOptions,
  ) {
    final headers = Map<String, dynamic>.of(requestOptions.headers);
    _removeHeader(headers, HttpHeaders.cookieHeader);
    final userAgent = _userAgentsByHost[requestOptions.uri.host];
    if (userAgent == null) {
      final defaultUserAgent = _headerValue(
        dio.options.headers,
        HttpHeaders.userAgentHeader,
      );
      if (defaultUserAgent == null) {
        _removeHeader(headers, HttpHeaders.userAgentHeader);
      } else {
        headers[HttpHeaders.userAgentHeader] = defaultUserAgent;
      }
    } else {
      _applyBypassReplayHeaders(
        headers,
        requestOptions.uri,
        userAgent: userAgent,
      );
    }

    final extra = _buildNoCacheExtra(requestOptions.extra)
      ..remove(_cfBypassSessionAppliedExtraKey)
      ..remove(_cfBypassRetriedExtraKey)
      ..remove(_cfStaleSessionRetriedExtraKey)
      ..[_cfNetworkProfileRetriedExtraKey] = true;
    return requestOptions.copyWith(headers: headers, extra: extra);
  }

  Object? _headerValue(Map<String, dynamic> headers, String name) {
    final lowerName = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lowerName) return entry.value;
    }
    return null;
  }

  RequestOptions _buildBypassReplayOptions(
    RequestOptions requestOptions, {
    required String? userAgent,
    required bool validation,
    Map<String, dynamic> extra = const {},
  }) {
    final headers = Map<String, dynamic>.of(requestOptions.headers);
    _removeHeader(headers, HttpHeaders.cookieHeader);
    _applyBypassReplayHeaders(
      headers,
      requestOptions.uri,
      userAgent: userAgent,
    );

    final replayExtra = validation
        ? _buildValidationExtra(requestOptions.extra)
        : Map<String, dynamic>.of(requestOptions.extra);
    replayExtra.addAll(extra);

    return requestOptions.copyWith(
      headers: headers,
      extra: replayExtra,
      responseType: validation
          ? ResponseType.plain
          : requestOptions.responseType,
      receiveDataWhenStatusError: validation
          ? true
          : requestOptions.receiveDataWhenStatusError,
      validateStatus: validation ? (_) => true : requestOptions.validateStatus,
    );
  }

  Future<void> _applyCookies(CfBypassResult result, Uri requestUri) async {
    final host = requestUri.host;
    final cookies = <Cookie>[
      for (final cookie in result.cookies) ...[
        _toCookie(cookie, fallbackDomain: host),
        if (CfCookieHelper.isBypassProofCookie(cookie.name))
          _toHostRootCookie(cookie),
      ],
    ];

    if (cookies.isNotEmpty) {
      await cookieJar.saveFromResponse(requestUri, cookies);
      final savedCookies = await cookieJar.loadForRequest(requestUri);
      _log.fineWithMetadata(
        "Saved CF bypass cookies to jar",
        metadata: {
          "host": host,
          "interceptorId": _interceptorId,
          "cookies": cookies.map(_cookieScope).toList(),
          "loadableCookies": savedCookies.map(_cookieScope).toList(),
        },
      );
    }
  }

  Cookie _toCookie(CfBrowserCookie cookie, {required String fallbackDomain}) {
    return Cookie(cookie.name, cookie.value)
      ..domain = cookie.domain.isNotEmpty ? cookie.domain : fallbackDomain
      ..path = cookie.path
      ..secure = cookie.isSecure ?? false
      ..httpOnly = cookie.isHttpOnly ?? false
      ..expires = cookie.expires;
  }

  Cookie _toHostRootCookie(CfBrowserCookie cookie) {
    return Cookie(cookie.name, cookie.value)
      ..path = '/'
      ..secure = cookie.isSecure ?? false
      ..httpOnly = cookie.isHttpOnly ?? false
      ..expires = cookie.expires;
  }

  Cookie _toStoredCookie(
    CfBypassStoredCookie cookie, {
    required String fallbackDomain,
  }) {
    return Cookie(cookie.name, cookie.value)
      ..domain = cookie.domain.isNotEmpty ? cookie.domain : fallbackDomain
      ..path = cookie.path
      ..secure = cookie.isSecure ?? false
      ..httpOnly = cookie.isHttpOnly ?? false
      ..expires = cookie.expires;
  }

  Cookie _toStoredHostRootCookie(CfBypassStoredCookie cookie) {
    return Cookie(cookie.name, cookie.value)
      ..path = '/'
      ..secure = cookie.isSecure ?? false
      ..httpOnly = cookie.isHttpOnly ?? false
      ..expires = cookie.expires;
  }

  Map<String, String?> _cookieScope(Cookie cookie) {
    return {"name": cookie.name, "domain": cookie.domain, "path": cookie.path};
  }

  void _removeHeader(Map<String, dynamic> headers, String name) {
    final lowerName = name.toLowerCase();
    headers.removeWhere((key, _) => key.toLowerCase() == lowerName);
  }

  void _applyBypassReplayHeaders(
    Map<String, dynamic> headers,
    Uri uri, {
    required String? userAgent,
  }) {
    if (userAgent != null) {
      headers["User-Agent"] = userAgent;
    }
    headers.putIfAbsent(
      "Accept",
      () => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    );
    headers.putIfAbsent("Accept-Language", () => "en-US,en;q=0.9");
    headers.putIfAbsent("Referer", () => "${uri.scheme}://${uri.host}/");
  }

  static String? _shortNetworkId(String? networkKey) {
    if (networkKey == null) return null;
    return networkKey.length <= 12 ? networkKey : networkKey.substring(0, 12);
  }
}
