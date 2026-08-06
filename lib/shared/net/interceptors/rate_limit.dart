import 'dart:async';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';

final _log = Logger("senpwai.net.interceptors.rate_limit");

class RateLimitInterceptor extends Interceptor {
  final Map<String, DateTime> _blockedUntil = {};
  final Dio dio;

  RateLimitInterceptor(this.dio);

  DateTime _now() => DateTime.now().toUtc();

  Duration _parseRetryAfter(Headers headers) {
    final retryAfter = headers.value("retry-after");

    if (retryAfter != null) {
      final seconds = int.tryParse(retryAfter);
      if (seconds != null) {
        return Duration(seconds: seconds);
      }

      final date = DateTime.tryParse(retryAfter);
      if (date != null) {
        return date.toUtc().difference(_now());
      }
    }

    final reset = headers.value("x-ratelimit-reset");
    if (reset != null) {
      final timestamp = int.tryParse(reset);
      if (timestamp != null) {
        final resetTime = DateTime.fromMillisecondsSinceEpoch(
          timestamp * 1000,
          isUtc: true,
        );
        return resetTime.difference(_now());
      }
    }

    return const Duration(seconds: 2);
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final host = options.uri.host;

    final blockedUntil = _blockedUntil[host];

    if (blockedUntil != null) {
      final delay = blockedUntil.difference(_now());

      if (delay.inMicroseconds > 0) {
        await Future<void>.delayed(delay);
      } else {
        _blockedUntil.remove(host);
      }
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;

    if (response?.statusCode == 429) {
      final uri = err.requestOptions.uri;
      final host = uri.host;

      var delay = _parseRetryAfter(response!.headers);

      if (delay.inMicroseconds <= 0) {
        delay = const Duration(seconds: 2);
      }
      _log.warningWithMetadata(
        'Rate limited; retrying request',
        metadata: {'host': host, 'delaySeconds': delay.inSeconds},
      );

      _blockedUntil[host] = _now().add(delay);

      await Future<void>.delayed(delay);

      try {
        final retryResponse = await dio.fetch<dynamic>(err.requestOptions);
        handler.resolve(retryResponse);
      } on DioException catch (retryErr) {
        handler.next(retryErr);
      }
      return;
    }

    handler.next(err);
  }
}
