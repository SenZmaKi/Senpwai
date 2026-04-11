import 'dart:async';

import 'package:cf_bypass/cf_bypass.dart' hide LoggerExtensions;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:senpwai/shared/log.dart';

final _log = Logger("senpwai.net.interceptors.cf_bypass");

/// Callback the UI layer provides to solve a CF challenge.
/// Takes the challenged URL, returns the bypass result from the WebView.
typedef CfBypassSolver = Future<CfBypassResult> Function(String url);

/// Dio interceptor that detects CloudFlare protection on error responses
/// and delegates challenge solving to a [CfBypassSolver] callback.
///
/// On successful bypass, cookies and user-agent are applied to the [CookieJar]
/// and the original request is retried transparently.
class CfBypassInterceptor extends Interceptor {
  final Dio dio;
  final CookieJar cookieJar;
  CfBypassSolver? _solver;

  CfBypassInterceptor({required this.dio, required this.cookieJar});

  /// Sets the solver callback. Typically called by the UI layer once
  /// it has a navigation context to show the [CfWebView].
  void setSolver(CfBypassSolver? solver) {
    _solver = solver;
    _log.info("CF bypass solver ${solver != null ? 'set' : 'cleared'}");
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

    final alreadyRetried = err.requestOptions.extra["cfBypassRetried"] == true;
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

    _log.info("Initiating CF bypass solve for $url");

    try {
      final result = await _solver!(url);

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

      _applyCookies(result, err.requestOptions.uri);

      if (result.userAgent != null) {
        dio.options.headers["User-Agent"] = result.userAgent;
      }

      final retryOptions = err.requestOptions.copyWith(
        extra: {...err.requestOptions.extra, "cfBypassRetried": true},
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

  void _applyCookies(CfBypassResult result, Uri requestUri) {
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
      cookieJar.saveFromResponse(requestUri, cookies);
      _log.fineWithMetadata(
        "Saved CF bypass cookies to jar",
        metadata: {
          "host": host,
          "cookies": cookies.map((c) => c.name).toList(),
        },
      );
    }
  }
}
