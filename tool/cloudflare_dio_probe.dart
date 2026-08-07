import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:senpwai/shared/net/http2_preferred_adapter.dart';

const _challengeMarkers = [
  'just a moment',
  'performing security verification',
  'challenge-platform',
  'cf_chl_',
];

Future<void> main() async {
  final environment = Platform.environment;
  final target = environment['CF_PROBE_URL'];
  final cookie = environment['CF_PROBE_COOKIE'];
  final userAgent = environment['CF_PROBE_UA'];
  final timeoutSeconds = int.tryParse(
    environment['CF_PROBE_TIMEOUT_SECONDS'] ?? '',
  );
  if (target == null || cookie == null || userAgent == null) {
    throw StateError(
      'CF_PROBE_URL, CF_PROBE_COOKIE, and CF_PROBE_UA are required',
    );
  }

  final timeout = Duration(seconds: timeoutSeconds ?? 45);
  final dio = Dio(
    BaseOptions(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      followRedirects: true,
      headers: {
        HttpHeaders.userAgentHeader: userAgent,
        HttpHeaders.cookieHeader: cookie,
      },
      validateStatus: (_) => true,
    ),
  );
  preferHttp2(dio);

  final stopwatch = Stopwatch()..start();
  try {
    final response = await dio.get<String>(target);
    stopwatch.stop();
    final body = response.data ?? '';
    final bodyLower = body.toLowerCase();
    stdout.writeln(
      jsonEncode({
        'probe': 'dio-http2-preferred',
        'status': response.statusCode,
        'protocol': response.extra[HttpClientAdapter.extraKeyHttpVersion],
        'elapsedMs': stopwatch.elapsedMilliseconds,
        'server': response.headers.value('server'),
        'cfMitigated': response.headers.value('cf-mitigated'),
        'contentType': response.headers.value('content-type'),
        'bodyBytes': utf8.encode(body).length,
        'challengeMarkers': [
          for (final marker in _challengeMarkers)
            if (bodyLower.contains(marker)) marker,
        ],
      }),
    );
  } on DioException catch (error) {
    stopwatch.stop();
    stdout.writeln(
      jsonEncode({
        'probe': 'dio-http2-preferred',
        'status': error.response?.statusCode,
        'protocol':
            error.response?.extra[HttpClientAdapter.extraKeyHttpVersion],
        'elapsedMs': stopwatch.elapsedMilliseconds,
        'errorType': error.type.name,
        'error': error.message,
      }),
    );
  } finally {
    dio.close(force: true);
  }
}
