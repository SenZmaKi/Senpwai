import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/net/net.dart';
import 'package:senpwai/shared/net/net_config.dart';

import 'support/support.dart';

const testUrl = "https://example.com";

void main() {
  setUpAll(() {
    setupLogger();
  });

  group("cache", () {
    test("cache fetches faster", () async {
      final dio = GlobalDio.getInstance();
      final uncached = await timeIt(
        label: "Fetching example.com (uncached)",
        fn: () => dio.get(testUrl),
      );
      final cached = await timeIt(
        label: "Fetching example.com (cached)",
        fn: () => dio.get(testUrl),
      );
      expect(cached.inMilliseconds, lessThan(uncached.inMilliseconds));
      NetConfig.getInstance().logCache();
    });

    test(
      "POST requests to same endpoint with different bodies use different cache entries",
      () async {
        NetConfig.getInstance().cacheStore = null;

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var postRequestCount = 0;

        server.listen((request) async {
          final body = await utf8.decoder.bind(request).join();
          if (request.method == 'POST') {
            postRequestCount++;
          }
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({'method': request.method, 'echo': body}),
          );
          await request.response.close();
        });

        final dio = Dio();
        try {
          NetConfig.getInstance().attachToDio(dio);
          final url = 'http://127.0.0.1:${server.port}/graphql';
          final cacheExtra = NetConfig.getInstance()
              .buildCacheOptions(allowPostMethod: true)
              .toExtra();

          final first = await dio.post<Map<String, dynamic>>(
            url,
            data: {'query': 'one'},
            options: Options(extra: cacheExtra),
          );
          final second = await dio.post<Map<String, dynamic>>(
            url,
            data: {'query': 'two'},
            options: Options(extra: cacheExtra),
          );
          final third = await dio.post<Map<String, dynamic>>(
            url,
            data: {'query': 'one'},
            options: Options(extra: cacheExtra),
          );

          expect(first.data?['echo'], contains('one'));
          expect(second.data?['echo'], contains('two'));
          expect(third.data?['echo'], contains('one'));
          expect(postRequestCount, equals(2));
        } finally {
          dio.close();
          await server.close(force: true);
        }
      },
    );
  });

  test("fetch example.com", () async {
    final response = await GlobalDio.getInstance().get(testUrl);
    expect(response.statusCode, 200);
  });
}
