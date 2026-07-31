import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/source_directory/source_directory.dart';

const skipCookieManagerExtraKey = 'skipCookieManager';

final _log = Logger("senpwai.net.interceptors.cookie_manager");

class AppCookieManager extends CookieManager {
  AppCookieManager(super.cookieJar);

  bool _shouldSkip(RequestOptions options) =>
      options.extra[skipCookieManagerExtraKey] == true;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_shouldSkip(options)) {
      _logIfUseful(
        "Cookie manager skipped request",
        options,
        extra: {"cookieNames": _cookieNamesFromHeaders(options.headers)},
      );
      handler.next(options);
      return;
    }
    await super.onRequest(options, handler);
    _logIfUseful(
      "Cookie manager loaded request cookies",
      options,
      extra: {"cookieNames": _cookieNamesFromHeaders(options.headers)},
    );
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    await super.onResponse(response, handler);
    _logIfUseful(
      "Cookie manager saved response cookies",
      response.requestOptions,
      extra: {
        "setCookieNames": _cookieNamesFromSetCookieHeaders(
          response.headers[HttpHeaders.setCookieHeader],
        ),
      },
    );
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requestOptions = err.response?.requestOptions ?? err.requestOptions;
    await super.onError(err, handler);
    _logIfUseful(
      "Cookie manager handled error response cookies",
      requestOptions,
      extra: {
        "statusCode": err.response?.statusCode,
        "setCookieNames": _cookieNamesFromSetCookieHeaders(
          err.response?.headers[HttpHeaders.setCookieHeader],
        ),
        "requestCookieNames": _cookieNamesFromHeaders(requestOptions.headers),
      },
    );
  }

  void _logIfUseful(
    String message,
    RequestOptions options, {
    Map<String, dynamic>? extra,
  }) {
    final host = options.uri.host;
    final cookieSourceHosts = {
      ...SourceDirectory.instance.animePahe.allowedHosts,
      ...SourceDirectory.instance.kwik.allowedHosts,
    };
    if (!cookieSourceHosts.contains(host) &&
        options.extra[skipCookieManagerExtraKey] != true) {
      return;
    }
    _log.infoWithMetadata(
      message,
      metadata: {
        "url": options.uri.toString(),
        "host": host,
        "skipCookieManager": options.extra[skipCookieManagerExtraKey] == true,
        ...?extra,
      },
    );
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
    return text
        .split(';')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && part.contains('='))
        .map((part) => part.substring(0, part.indexOf('=')).trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _cookieNamesFromSetCookieHeaders(List<String>? headers) {
    if (headers == null) return const [];
    return headers
        .map((header) {
          final eqIdx = header.indexOf('=');
          if (eqIdx <= 0) return null;
          return header.substring(0, eqIdx).trim();
        })
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }
}
