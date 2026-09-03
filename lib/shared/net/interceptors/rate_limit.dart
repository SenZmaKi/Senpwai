import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';

final _log = Logger("senpwai.net.interceptors.rate_limit");

const _rateLimitRetriedExtraKey = 'rateLimitRetried';

bool isCloudflare1015Response(Response<dynamic> response) {
  final errorType = response.headers.value('cf-error-type');
  if (errorType?.trim() == '1015') return true;

  final data = response.data;
  if (data is Map && data['error_code'].toString() == '1015') return true;
  if (data is! String) return false;

  final body = data.toLowerCase();
  return body.contains('error 1015') ||
      body.contains('cf-error-code: 1015') ||
      body.contains('cf-error-code="1015"');
}

class RateLimitInterceptor extends Interceptor {
  final Map<String, DateTime> _blockedUntil = {};
  final Map<String, Future<void>> _cooldowns = {};
  final Dio dio;

  RateLimitInterceptor(this.dio);

  DateTime _now() => DateTime.now().toUtc();

  Duration _parseRetryAfter(Headers headers, {required Duration fallback}) {
    final retryAfter = headers.value("retry-after");

    if (retryAfter != null) {
      final seconds = int.tryParse(retryAfter);
      if (seconds != null) {
        return Duration(seconds: seconds);
      }

      try {
        return HttpDate.parse(retryAfter).toUtc().difference(_now());
      } on FormatException {
        // Continue to the remaining headers and fallback.
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

    return fallback;
  }

  Future<void> _waitForHostCooldown(String host, Duration delay) {
    final proposedDeadline = _now().add(delay);
    final currentDeadline = _blockedUntil[host];
    if (currentDeadline == null || proposedDeadline.isAfter(currentDeadline)) {
      _blockedUntil[host] = proposedDeadline;
    }

    final existing = _cooldowns[host];
    if (existing != null) return existing;

    late final Future<void> cooldown;
    cooldown = _drainHostCooldown(host).whenComplete(() {
      if (identical(_cooldowns[host], cooldown)) {
        _cooldowns.remove(host);
      }
    });
    _cooldowns[host] = cooldown;
    return cooldown;
  }

  Future<void> _drainHostCooldown(String host) async {
    while (true) {
      final deadline = _blockedUntil[host];
      if (deadline == null) return;
      final remaining = deadline.difference(_now());
      if (remaining.inMicroseconds <= 0) {
        _blockedUntil.remove(host);
        return;
      }
      await Future<void>.delayed(remaining);
    }
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final host = options.uri.host;

    final blockedUntil = _blockedUntil[host];

    if (blockedUntil != null) {
      await _waitForHostCooldown(host, Duration.zero);
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;

    final isHttp429 = response?.statusCode == HttpStatus.tooManyRequests;
    final isCloudflare1015 =
        response != null && isCloudflare1015Response(response);

    if (response != null && (isHttp429 || isCloudflare1015)) {
      final uri = err.requestOptions.uri;
      final host = uri.host;

      if (err.requestOptions.extra[_rateLimitRetriedExtraKey] == true) {
        _log.warningWithMetadata(
          'Rate limit persisted after retry',
          metadata: {
            'host': host,
            'statusCode': response.statusCode,
            'cloudflareError': isCloudflare1015 ? 1015 : null,
          },
        );
        handler.next(err);
        return;
      }

      var delay = _parseRetryAfter(
        response.headers,
        fallback: isCloudflare1015
            ? const Duration(seconds: 30)
            : const Duration(seconds: 2),
      );

      if (delay.inMicroseconds <= 0) {
        delay = const Duration(seconds: 2);
      }
      _log.warningWithMetadata(
        'Rate limited; retrying request',
        metadata: {
          'host': host,
          'statusCode': response.statusCode,
          'cloudflareError': isCloudflare1015 ? 1015 : null,
          'delaySeconds': delay.inSeconds,
        },
      );

      await _waitForHostCooldown(host, delay);

      try {
        final retryOptions = err.requestOptions.copyWith(
          extra: {...err.requestOptions.extra, _rateLimitRetriedExtraKey: true},
        );
        final retryResponse = await dio.fetch<dynamic>(retryOptions);
        handler.resolve(retryResponse);
      } on DioException catch (retryErr) {
        handler.next(retryErr);
      }
      return;
    }

    handler.next(err);
  }
}
