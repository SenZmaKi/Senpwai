import 'dart:convert';
import 'dart:io';

import 'package:cf_bypass/cf_bypass.dart' hide LoggerExtensions;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:crypto/crypto.dart';
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
  }

  /// Sets the solver callback. Typically called by the UI layer once
  /// it has a navigation context to show the [CfWebView].
  void setSolver(CfBypassSolver? solver) {
    _solver = solver;
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

    _log.warningWithMetadata(
      'Cloudflare protection detected',
      metadata: {
        'url': url,
        'host': err.requestOptions.uri.host,
        'statusCode': statusCode,
        'httpVersion': response.extra[HttpClientAdapter.extraKeyHttpVersion],
        'kind': detection.kind.name,
        'matchedIndicators': detection.matchedIndicators,
        'hasBypassSession': _hasBypassSession(err.requestOptions.uri.host),
        'userAgentFingerprint': _fingerprint(
          _headerValue(
            err.requestOptions.headers,
            HttpHeaders.userAgentHeader,
          )?.toString(),
        ),
        'requestCookieNames': _cookieNames(
          _headerValue(err.requestOptions.headers, HttpHeaders.cookieHeader),
        ),
        'requestHeaders': _safeRequestHeaders(err.requestOptions.headers),
        'responseBodyBytes': body?.length,
        'responseBodyFingerprint': _fingerprint(body),
        'server': response.headers.value('server'),
        'cfMitigated': response.headers.value('cf-mitigated'),
        'contentType': response.headers.value('content-type'),
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
        "CloudFlare hard block — attempting WebView mitigation",
        metadata: {
          "url": url,
          "interceptorId": _interceptorId,
          "cleanRetryAttempted": staleSessionAlreadyRetried,
        },
      );
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
      _log.warning("CF protection detected but no solver set — cannot bypass");
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
          'host': err.requestOptions.uri.host,
          'cookieCount': result.cookies.length,
          'durationMs': result.duration?.inMilliseconds,
        },
      );

      final sessionUri = _resolvedSessionUri(result, err.requestOptions.uri);
      await _applyCookies(result, sessionUri);
      _bypassedHosts.add(sessionUri.host);

      if (result.userAgent != null) {
        _userAgentsByHost[sessionUri.host] = result.userAgent!;
      }
      await _rememberSession(sessionUri.host, result);

      final retryOptions = _buildBypassReplayOptions(
        err.requestOptions,
        userAgent: result.userAgent,
        validation: false,
        targetUri: _resolvedReplayUri(result, err.requestOptions.uri),
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
      return existingBypass;
    }

    final solver = _solver;
    if (solver == null) {
      throw StateError("CF bypass solver is not set");
    }

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

    final sessionUri = _resolvedSessionUri(result, requestOptions.uri);
    await _applyCookies(result, sessionUri);

    final validationOptions = _buildBypassReplayOptions(
      requestOptions,
      userAgent: result.userAgent,
      validation: true,
      targetUri: _resolvedReplayUri(result, requestOptions.uri),
    );
    final storedCookieNames = (await cookieJar.loadForRequest(
      validationOptions.uri,
    )).map((cookie) => cookie.name).toSet().toList()..sort();
    final expectedUserAgentFingerprint = _fingerprint(result.userAgent);

    _log.infoWithMetadata(
      "CF bypass validation request prepared",
      metadata: {
        "url": validationOptions.uri.toString(),
        "interceptorId": _interceptorId,
        "expectedUserAgentFingerprint": expectedUserAgentFingerprint,
        "storedCookieNames": storedCookieNames,
        "requestHeaders": _safeRequestHeaders(validationOptions.headers),
      },
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
      final outgoingUserAgent = _headerValue(
        response.requestOptions.headers,
        HttpHeaders.userAgentHeader,
      )?.toString();

      _log.infoWithMetadata(
        "CF bypass validation response received",
        metadata: {
          "url": response.realUri.toString(),
          "interceptorId": _interceptorId,
          "statusCode": statusCode,
          "httpVersion": response.extra[HttpClientAdapter.extraKeyHttpVersion],
          "protectionKind": detection.kind.name,
          "verified": verified,
          "expectedUserAgentFingerprint": expectedUserAgentFingerprint,
          "outgoingUserAgentFingerprint": _fingerprint(outgoingUserAgent),
          "userAgentMatchesExpected": outgoingUserAgent == result.userAgent,
          "requestCookieNames": _cookieNames(
            _headerValue(
              response.requestOptions.headers,
              HttpHeaders.cookieHeader,
            ),
          ),
          "requestHeaders": _safeRequestHeaders(
            response.requestOptions.headers,
          ),
          "storedCookieNames": storedCookieNames,
          "cfMitigated": response.headers.value('cf-mitigated'),
          "responseBodyBytes": body?.length,
          "responseBodyFingerprint": _fingerprint(body),
          "server": response.headers.value('server'),
          "contentType": response.headers.value('content-type'),
        },
      );

      return verified;
    } catch (e, stack) {
      final dioError = e is DioException ? e : null;
      final failedResponse = dioError?.response;
      final failedRequest = dioError?.requestOptions ?? validationOptions;
      final outgoingUserAgent = _headerValue(
        failedRequest.headers,
        HttpHeaders.userAgentHeader,
      )?.toString();
      _log.warningWithMetadata(
        "CF bypass validation request failed",
        metadata: {
          "url": requestOptions.uri.toString(),
          "interceptorId": _interceptorId,
          "statusCode": failedResponse?.statusCode,
          "httpVersion":
              failedResponse?.extra[HttpClientAdapter.extraKeyHttpVersion],
          "expectedUserAgentFingerprint": expectedUserAgentFingerprint,
          "outgoingUserAgentFingerprint": _fingerprint(outgoingUserAgent),
          "userAgentMatchesExpected": outgoingUserAgent == result.userAgent,
          "requestCookieNames": _cookieNames(
            _headerValue(failedRequest.headers, HttpHeaders.cookieHeader),
          ),
          "requestHeaders": _safeRequestHeaders(failedRequest.headers),
          "storedCookieNames": storedCookieNames,
          "cfMitigated": failedResponse?.headers.value('cf-mitigated'),
          "responseBodyBytes": failedResponse?.data is String
              ? (failedResponse!.data as String).length
              : null,
          "responseBodyFingerprint": failedResponse?.data is String
              ? _fingerprint(failedResponse!.data as String)
              : null,
          "server": failedResponse?.headers.value('server'),
          "contentType": failedResponse?.headers.value('content-type'),
          "error": e.toString(),
          "stackTrace": stack.toString(),
        },
      );
      return false;
    }
  }

  bool _isValidationRequest(RequestOptions options) =>
      options.extra[_cfBypassValidationExtraKey] == true;

  Uri _resolvedSessionUri(CfBypassResult result, Uri fallback) {
    final resolved = Uri.tryParse(result.finalUrl);
    if (resolved == null ||
        resolved.host.isEmpty ||
        (resolved.scheme != 'http' && resolved.scheme != 'https')) {
      _log.warningWithMetadata(
        "CF bypass returned an invalid resolved URL; using request URL",
        metadata: {
          "finalUrl": result.finalUrl,
          "requestUrl": fallback.toString(),
          "interceptorId": _interceptorId,
        },
      );
      return fallback;
    }
    return resolved;
  }

  Uri _resolvedReplayUri(CfBypassResult result, Uri requestUri) {
    final resolved = _resolvedSessionUri(result, requestUri);
    if (resolved.host == requestUri.host) return requestUri;
    return resolved.replace(
      path: requestUri.path,
      query: requestUri.hasQuery ? requestUri.query : null,
      fragment: '',
    );
  }

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

      final cookies = [
        for (final storedCookie in session.cookies)
          _toStoredCookie(storedCookie, fallbackDomain: host),
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
        ]).then<void>((_) {}).whenComplete(() {
          _sessionResetByHost.remove(host);
        });
    _sessionResetByHost[host] = reset;
    return reset;
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

  String? _fingerprint(String? value) {
    if (value == null || value.isEmpty) return null;
    return sha256.convert(utf8.encode(value)).toString().substring(0, 12);
  }

  List<String> _cookieNames(Object? headerValue) {
    if (headerValue == null) return const [];
    final value = headerValue is Iterable
        ? headerValue.join(';')
        : headerValue.toString();
    final names =
        value
            .split(';')
            .map((part) => part.trim())
            .where((part) => part.contains('='))
            .map((part) => part.substring(0, part.indexOf('=')))
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return names;
  }

  Map<String, String> _safeRequestHeaders(Map<String, dynamic> headers) {
    const allowedNames = {
      'accept',
      'accept-encoding',
      'accept-language',
      'content-type',
      'origin',
      'referer',
    };
    return {
      for (final entry in headers.entries)
        if (allowedNames.contains(entry.key.toLowerCase()))
          entry.key.toLowerCase(): entry.value.toString(),
    };
  }

  RequestOptions _buildBypassReplayOptions(
    RequestOptions requestOptions, {
    required String? userAgent,
    required bool validation,
    Uri? targetUri,
    Map<String, dynamic> extra = const {},
  }) {
    final replayUri = targetUri ?? requestOptions.uri;
    final headers = Map<String, dynamic>.of(requestOptions.headers);
    _removeHeader(headers, HttpHeaders.cookieHeader);
    _applyBypassReplayHeaders(headers, replayUri, userAgent: userAgent);

    final replayExtra = validation
        ? _buildValidationExtra(requestOptions.extra)
        : Map<String, dynamic>.of(requestOptions.extra);
    replayExtra.addAll(extra);

    return requestOptions.copyWith(
      baseUrl: '${replayUri.scheme}://${replayUri.authority}',
      path: replayUri.path,
      queryParameters: replayUri.queryParametersAll,
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
    final cookies = [
      for (final cookie in result.cookies)
        _toCookie(cookie, fallbackDomain: host),
    ];

    if (cookies.isNotEmpty) {
      await cookieJar.saveFromResponse(requestUri, cookies);
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
}
