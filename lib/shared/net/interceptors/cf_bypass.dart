import 'dart:async';
import 'dart:io';

import 'package:cf_bypass/cf_bypass.dart' hide LoggerExtensions;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/interceptors/cookie_manager.dart';
import 'package:senpwai/shared/net/net_config.dart';

final _log = Logger("senpwai.net.interceptors.cf_bypass");

const _cfBypassRetriedExtraKey = 'cfBypassRetried';
const _cfBypassValidationExtraKey = 'cfBypassValidation';

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
  CfBypassSolver? _solver;
  final Map<String, String> _userAgentsByHost = {};
  final Map<String, Future<CfBypassResult>> _bypassByHost = {};

  CfBypassInterceptor({required this.dio, required this.cookieJar});

  /// Sets the solver callback. Typically called by the UI layer once
  /// it has a navigation context to show the [CfWebView].
  void setSolver(CfBypassSolver? solver) {
    _solver = solver;
    _log.info("CF bypass solver ${solver != null ? 'set' : 'cleared'}");
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final userAgent = _isValidationRequest(options)
        ? null
        : _userAgentsByHost[options.uri.host];
    if (userAgent != null && !options.headers.containsKey("User-Agent")) {
      options.headers["User-Agent"] = userAgent;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
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
    if (alreadyRetried) {
      _log.warningWithMetadata(
        "CF bypass already retried, passing through",
        metadata: {"url": err.requestOptions.uri.toString()},
      );
      handler.next(err);
      return;
    }

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
        "kind": detection.kind.name,
        "indicators": detection.matchedIndicators,
      },
    );

    if (detection.kind == CfProtectionKind.blocked) {
      _log.warningWithMetadata(
        "CloudFlare hard block — cannot bypass",
        metadata: {"url": url},
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
          metadata: {"url": url, "error": result.error},
        );
        handler.next(err);
        return;
      }

      _log.infoWithMetadata(
        "CF bypass succeeded",
        metadata: {
          "url": url,
          "userAgent": result.userAgent,
          "cookieCount": result.cookies.length,
          "duration": result.duration?.inMilliseconds,
        },
      );

      await _applyCookies(result, err.requestOptions.uri);

      if (result.userAgent != null) {
        _userAgentsByHost[err.requestOptions.uri.host] = result.userAgent!;
      }

      final retryOptions = err.requestOptions.copyWith(
        headers: _buildRetryHeaders(err.requestOptions, result),
        extra: {...err.requestOptions.extra, _cfBypassRetriedExtraKey: true},
      );

      final retryResponse = await dio.fetch<dynamic>(retryOptions);
      handler.resolve(retryResponse);
    } catch (e, stack) {
      _log.severeWithMetadata(
        "CF bypass solver threw",
        error: e,
        stackTrace: stack,
        metadata: {"url": url},
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
        metadata: {"host": host, "url": url},
      );
      return existingBypass;
    }

    final solver = _solver;
    if (solver == null) {
      throw StateError("CF bypass solver is not set");
    }

    _log.infoWithMetadata(
      "Initiating CF bypass solve",
      metadata: {"host": host, "url": url},
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

    final headers = _buildRetryHeaders(requestOptions, result);
    if (result.cookies.isNotEmpty) {
      headers[HttpHeaders.cookieHeader] = CfCookieHelper.cookiesToHeader(
        result.cookies,
      );
    }
    final validationOptions = requestOptions.copyWith(
      headers: headers,
      extra: _buildValidationExtra(requestOptions.extra),
      responseType: ResponseType.plain,
      receiveDataWhenStatusError: true,
      validateStatus: (_) => true,
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
      final verified =
          (response.statusCode ?? 0) > 0 &&
          detection.kind == CfProtectionKind.none;

      _log.infoWithMetadata(
        verified
            ? "CF bypass validation passed"
            : "CF bypass validation failed",
        metadata: {
          "url": requestOptions.uri.toString(),
          "statusCode": response.statusCode,
          "kind": detection.kind.name,
          "indicators": detection.matchedIndicators,
        },
      );
      return verified;
    } catch (e, stack) {
      _log.warningWithMetadata(
        "CF bypass validation request failed",
        metadata: {
          "url": requestOptions.uri.toString(),
          "error": e.toString(),
          "stackTrace": stack.toString(),
        },
      );
      return false;
    }
  }

  bool _isValidationRequest(RequestOptions options) =>
      options.extra[_cfBypassValidationExtraKey] == true;

  Map<String, dynamic> _buildValidationExtra(Map<String, dynamic> extra) {
    return {
      ...extra,
      _cfBypassValidationExtraKey: true,
      skipCookieManagerExtraKey: true,
      ...NetConfig.getInstance()
          .buildCacheOptions(policy: CachePolicy.noCache)
          .toExtra(),
    };
  }

  Future<void> _applyCookies(CfBypassResult result, Uri requestUri) async {
    final host = requestUri.host;
    final cookies = result.cookies
        .map(
          (c) => Cookie(c.name, c.value)
            ..domain = c.domain.isNotEmpty ? c.domain : host
            ..path = c.path
            ..secure = c.isSecure ?? false
            ..httpOnly = c.isHttpOnly ?? false
            ..expires = c.expires,
        )
        .toList();

    if (cookies.isNotEmpty) {
      await cookieJar.saveFromResponse(requestUri, cookies);
      _log.fineWithMetadata(
        "Saved CF bypass cookies to jar",
        metadata: {
          "host": host,
          "cookies": cookies.map((c) => c.name).toList(),
        },
      );
    }
  }

  Map<String, dynamic> _buildRetryHeaders(
    RequestOptions requestOptions,
    CfBypassResult result,
  ) {
    final headers = Map<String, dynamic>.of(requestOptions.headers);

    if (result.userAgent != null) {
      headers["User-Agent"] = result.userAgent;
    }

    headers.putIfAbsent(
      "Accept",
      () => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    );
    headers.putIfAbsent("Accept-Language", () => "en-US,en;q=0.9");
    headers.putIfAbsent(
      "Referer",
      () => "${requestOptions.uri.scheme}://${requestOptions.uri.host}/",
    );

    return headers;
  }
}
